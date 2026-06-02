import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
import UIKit
#endif

/// PHOTO-OF-NOTES — reusable photo affordance for any reflection free-text field.
///
/// Drops next to the dictation mic on a `TextField`. Tapping offers two sources:
///   • Camera (iOS-only `CameraCaptureView`) — snap a photo of handwritten/printed notes.
///   • Photo Library (`PhotosPicker`, cross-platform) — pick an existing photo.
/// The chosen image is OCR'd ON-DEVICE via `OCRService` (Vision); the recognized text is
/// surfaced in a confirmation sheet where the user can accept (append it into the bound
/// `$text`) or skip. Either way the photo + its recognized text are persisted as a
/// `ReflectionPhoto` attached to today's `Reflection` (resolved lazily via `reflection()`),
/// and shown as a thumbnail strip under the field.
///
/// Lives under Views/ (excluded from the mac target). The camera path is `#if os(iOS)`;
/// the library + OCR paths are cross-platform but this view is iOS-only in practice.
struct ReflectionPhotoButton: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    /// Bound free-text the recognized text is appended into when the user accepts.
    @Binding var text: String
    /// Lazily resolves (creating if needed) the reflection the photo attaches to. Only
    /// invoked when a photo is actually added, so we never create an empty reflection.
    let reflection: () -> Reflection

    @State private var showSourceDialog = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?

    /// OCR review state: the freshly attached photo awaiting accept/skip of its text.
    @State private var pendingRecognizedText: String = ""
    @State private var showRecognitionReview = false
    @State private var isProcessing = false

    var body: some View {
        let t = tm.resolved
        Button {
            showSourceDialog = true
        } label: {
            ZStack {
                Image(systemName: isProcessing ? "circle.dotted" : "camera")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isProcessing ? t.accent : t.muted)
                    .symbolEffect(.pulse, isActive: isProcessing)
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .accessibilityLabel("Attach a photo of your notes")
        .confirmationDialog("Add a photo of your notes", isPresented: $showSourceDialog, titleVisibility: .visible) {
            #if os(iOS)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            #endif
            PhotosPicker("Choose from Library", selection: $photoItem, matching: .images)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The photo is read on-device. Nothing is uploaded.")
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                Task { await handleCaptured(image) }
            }
            .ignoresSafeArea()
        }
        #endif
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePicked(newItem) }
        }
        .sheet(isPresented: $showRecognitionReview) {
            RecognitionReviewSheet(
                recognizedText: pendingRecognizedText,
                onInsert: { appendRecognized(pendingRecognizedText) }
            )
            .environment(tm)
        }
    }

    // MARK: - Capture handling

    #if os(iOS)
    private func handleCaptured(_ image: UIImage) async {
        isProcessing = true
        let recognized = await OCRService.recognizeText(in: image)
        persist(imageData: downscaledJPEG(image), recognizedText: recognized)
        finish(recognized)
    }
    #endif

    private func handlePicked(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            isProcessing = false
            return
        }
        #if os(iOS)
        guard let image = UIImage(data: data) else { isProcessing = false; return }
        let recognized = await OCRService.recognizeText(in: image)
        persist(imageData: downscaledJPEG(image), recognizedText: recognized)
        finish(recognized)
        #else
        // Library-pick OCR is cross-platform, but this view ships only on iOS.
        let recognized = await OCRService.recognizeTextFromData(data)
        persist(imageData: data, recognizedText: recognized)
        finish(recognized)
        #endif
    }

    private func finish(_ recognized: String) {
        isProcessing = false
        Haptics.success()
        let trimmed = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            pendingRecognizedText = trimmed
            showRecognitionReview = true
        }
    }

    // MARK: - Persistence

    private func persist(imageData: Data?, recognizedText: String) {
        let r = reflection()
        if r.modelContext == nil {
            modelContext.insert(r)
        }
        let photo = ReflectionPhoto(imageData: imageData, recognizedText: recognizedText)
        photo.reflection = r
        if r.photos == nil { r.photos = [] }
        r.photos?.append(photo)
        modelContext.insert(photo)
        try? modelContext.save()
    }

    /// Appends recognized text onto the bound field, separating from existing text.
    private func appendRecognized(_ recognized: String) {
        let spoken = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = spoken
        } else {
            let needsBreak = !text.hasSuffix("\n")
            text += (needsBreak ? "\n" : "") + spoken
        }
        Haptics.light()
    }

    // MARK: - Downscale

    #if os(iOS)
    /// Downscales (longest side ~1600pt) + JPEG-encodes the captured image so the
    /// CloudKit-synced external-storage blob stays light.
    private func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return scaled.jpegData(compressionQuality: quality)
    }
    #endif
}

/// Confirmation sheet shown after OCR: previews the recognized text and offers to insert
/// it into the reflection (the user can still edit the field afterward). Keeps the action
/// explicit so OCR never silently rewrites what the user typed.
private struct RecognitionReviewSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.dismiss) private var dismiss
    let recognizedText: String
    let onInsert: () -> Void

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Read from your photo, on-device.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(t.muted)
                        Text(recognizedText)
                            .font(t.body(14))
                            .foregroundStyle(t.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Recognized text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                        .foregroundStyle(t.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") { onInsert(); dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(t.accent)
                }
            }
        }
    }
}
