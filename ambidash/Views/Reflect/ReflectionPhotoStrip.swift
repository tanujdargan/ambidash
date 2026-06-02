import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#endif

/// PHOTO-OF-NOTES — horizontal thumbnail strip of the photos attached to a reflection.
/// Renders nothing when there are no photos, so it can be dropped unconditionally under
/// a field. Tapping a thumbnail opens a full-screen preview; the trash affordance removes
/// the photo (cascade-safe — it's a child of the reflection).
///
/// iOS-only image rendering (`UIImage`); lives under Views/ (excluded from the mac target).
struct ReflectionPhotoStrip: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    /// The reflection whose photos to show. Nil (no reflection yet) renders nothing.
    let reflection: Reflection?

    @State private var previewPhoto: ReflectionPhoto?

    private var photos: [ReflectionPhoto] {
        (reflection?.photos ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        let t = tm.resolved
        if !photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        thumbnail(photo, t)
                    }
                }
                .padding(.vertical, 2)
            }
            .sheet(item: $previewPhoto) { photo in
                PhotoPreviewSheet(photo: photo, onDelete: { delete(photo) })
                    .environment(tm)
            }
        }
    }

    @ViewBuilder
    private func thumbnail(_ photo: ReflectionPhoto, _ t: ResolvedTheme) -> some View {
        Button {
            previewPhoto = photo
        } label: {
            ZStack {
                #if os(iOS)
                if let data = photo.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder(t)
                }
                #else
                placeholder(t)
                #endif
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.hair, lineWidth: 0.5))
            .overlay(alignment: .bottomTrailing) {
                if !photo.recognizedText.isEmpty {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(t.accent, in: Circle())
                        .padding(3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo.recognizedText.isEmpty ? "Photo of notes" : "Photo of notes with recognized text")
    }

    @ViewBuilder
    private func placeholder(_ t: ResolvedTheme) -> some View {
        t.sunken.opacity(0.5)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundStyle(t.faint)
            )
    }

    private func delete(_ photo: ReflectionPhoto) {
        reflection?.photos?.removeAll { $0.id == photo.id }
        modelContext.delete(photo)
        try? modelContext.save()
        previewPhoto = nil
        Haptics.light()
    }
}

/// Full-screen preview of a single attached photo + its recognized text.
private struct PhotoPreviewSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.dismiss) private var dismiss
    let photo: ReflectionPhoto
    let onDelete: () -> Void

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        #if os(iOS)
                        if let data = photo.imageData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        #endif
                        if !photo.recognizedText.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("RECOGNIZED · ON-DEVICE")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundStyle(t.muted)
                                Text(photo.recognizedText)
                                    .font(t.body(14))
                                    .foregroundStyle(t.ink2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(t.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(t.accent)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) { onDelete() } label: {
                        Image(systemName: "trash")
                    }
                    .foregroundStyle(t.muted)
                }
            }
        }
    }
}
