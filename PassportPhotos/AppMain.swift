
import SwiftUI

@main
struct AppMain: App {
  var body: some Scene {
    WindowGroup {
      FaceVerificationView(model: CameraViewModel())
    }
  }
}
