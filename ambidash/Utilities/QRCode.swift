import SwiftUI

#if os(iOS)
import CoreImage.CIFilterBuiltins
import UIKit

/// Generates a QR image from a string, on-device (CoreImage — no network). Used by
/// the mentor invite so a code can be scanned phone-to-phone.
enum QRCode {
    private static let context = CIContext()

    static func image(from string: String) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return Image(uiImage: UIImage(cgImage: cg)).interpolation(.none)
    }
}
#else
enum QRCode {
    /// macOS: no QR rendering (the invite is a phone-to-phone flow); callers fall
    /// back to showing the code text.
    static func image(from string: String) -> Image? { nil }
}
#endif
