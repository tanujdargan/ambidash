import Foundation
@preconcurrency import Vision
import ImageIO

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// ON-DEVICE OCR — extracts text from a photo of the user's notes using Vision's
/// `VNRecognizeTextRequest`. Vision runs FULLY on-device by default (no entitlement,
/// no network), so this honors the privacy-by-construction mandate: a photo's contents
/// never leave the device.
///
/// Cross-platform: Vision exists on both iOS and macOS, so this service compiles into
/// both targets. The only platform split is the source image type (`UIImage` vs
/// `NSImage`), handled by the `recognizeText(in:)` overloads + a shared `CGImage` core.
enum OCRService {

    /// Runs accurate, language-corrected on-device text recognition over a `CGImage` and
    /// returns the recognized lines joined by newlines (empty when nothing legible).
    static func recognizeText(in cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            // Vision's perform is synchronous + can be heavy; keep it off the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    /// Convenience overload for raw image `Data` (cross-platform photo-library path).
    /// Decodes to a `CGImage` via ImageIO so it works identically on iOS and macOS.
    static func recognizeTextFromData(_ data: Data) async -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return ""
        }
        return await recognizeText(in: cgImage)
    }

    #if os(iOS)
    /// Convenience overload for a captured/picked `UIImage`.
    static func recognizeText(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await recognizeText(in: cgImage)
    }
    #elseif os(macOS)
    /// Convenience overload for an `NSImage` (macOS photo-library path).
    static func recognizeText(in image: NSImage) async -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "" }
        return await recognizeText(in: cgImage)
    }
    #endif
}
