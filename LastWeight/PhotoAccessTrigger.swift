import SwiftUI
import UIKit

struct PhotoAccessTriggerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIImagePickerController()
        controller.sourceType = .photoLibrary
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
