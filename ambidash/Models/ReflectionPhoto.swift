import Foundation
import SwiftData

/// PHOTO-OF-NOTES — a photo a user attached to a daily reflection, plus the text
/// extracted from it by ON-DEVICE OCR (Vision `VNRecognizeTextRequest`). The user
/// can snap their handwritten/printed notes (camera, iOS-only) or pick from the
/// photo library and have the recognized text offered for insertion into the
/// reflection's free-text.
///
/// CHILD record on purpose: the (potentially heavy) image blob lives here, off the
/// parent `Reflection` row, and a reflection can carry MANY photos. The blob is
/// `@Attribute(.externalStorage)` so SwiftData/SQLite (and CloudKit) keep it out of
/// the row and store/sync it as a file.
///
/// CloudKit-safe (additive-only): every scalar is defaulted, `imageData` is optional,
/// and the `reflection` relationship is optional with the inverse declared HERE on the
/// child side. The cascade delete-rule lives on the `Reflection.photos` parent side.
/// Registered in BOTH ModelContainers (AmbidashApp.swift + AmbidashMacApp.swift).
@Model
final class ReflectionPhoto {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    /// The attached image. Optional + external-storage to keep the blob off the row
    /// (lighter SQLite + CloudKit sync). Downscaled before persistence at the call site.
    @Attribute(.externalStorage) var imageData: Data?

    /// Text extracted from the image by on-device Vision OCR. Empty until OCR runs (or
    /// when nothing legible is found). Persisted so the recognized text survives even if
    /// the user never inserted it into the reflection free-text.
    var recognizedText: String = ""

    /// Child side of the relationship; carries the inverse to `Reflection.photos`.
    /// Optional + additive per the CloudKit rule.
    @Relationship(inverse: \Reflection.photos) var reflection: Reflection?

    init(id: UUID = UUID(), createdAt: Date = .now, imageData: Data? = nil, recognizedText: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.imageData = imageData
        self.recognizedText = recognizedText
    }
}
