#if os(iOS)
import SwiftUI
import UIKit

/// PHOTO-OF-NOTES (camera path, iOS-only) — a thin `UIImagePickerController` wrapper
/// that opens the device camera and hands back the captured `UIImage`. Lives under
/// Views/ (excluded from the mac target), and the whole file is `#if os(iOS)`-guarded
/// for belt-and-suspenders since `UIImagePickerController` is iOS-only.
///
/// We use `UIImagePickerController` (not a raw `AVCaptureSession`) deliberately: it's the
/// smallest correct camera-capture surface, ships system shutter UI, and needs no manual
/// session/preview-layer/orientation handling. The picked image is OCR'd on-device by the
/// caller; nothing is uploaded.
struct CameraCaptureView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
