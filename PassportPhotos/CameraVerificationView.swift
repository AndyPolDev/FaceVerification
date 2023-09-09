
import SwiftUI

struct CameraVerificationView: UIViewControllerRepresentable {
  typealias UIViewControllerType = CameraVerificationViewController

  private(set) var model: CameraViewModel

  func makeUIViewController(context: Context) -> CameraVerificationViewController {
    let faceDetector = FaceDetector()
    faceDetector.model = model

    let viewController = CameraVerificationViewController()
    viewController.faceDetector = faceDetector

    return viewController
  }

  func updateUIViewController(_ uiViewController: CameraVerificationViewController, context: Context) { }
}
