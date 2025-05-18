import SwiftUI
import PhotosUI

struct PhotoPermissionRequestView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoPermissionRequestView

        init(parent: PhotoPermissionRequestView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker regardless of selection
            picker.dismiss(animated: true) {
                self.parent.presentationMode.wrappedValue.dismiss()

                // Check photo permission status again
                if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
                    print("⚠️ Still in limited mode — prompt to upgrade access.")
                    self.parent.onLimitedAccessDetected()
                } else {
                    print("✅ Full access granted.")
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    var onLimitedAccessDetected: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}
