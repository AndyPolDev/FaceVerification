//Главное view swiftUI


import SwiftUI

struct FaceVerificationView: View {
  @ObservedObject private(set) var model: CameraViewModel

  init(model: CameraViewModel) {
    self.model = model
  }

  var body: some View {
    GeometryReader { geometry in
      NavigationView {
        ZStack {
          CameraVerificationView(model: model)
          LayoutGuideView(
            layoutGuideFrame: model.faceLayoutGuideFrame,
            hasDetectedValidFace: model.hasDetectedValidFace
          )
          if model.debugModeEnabled {
            DebugView(model: model)
          }
          CameraOverlayView(model: model)
        }
        .ignoresSafeArea()
        .onAppear {
          model.perform(action: .windowSizeDetected(geometry.frame(in: .global)))
        }
      }
    }
  }
}

// Отображает зеленый/красный овал необходимо заменить на фрейм "лица"

struct LayoutGuideView: View {
  let layoutGuideFrame: CGRect
  let hasDetectedValidFace: Bool

  var body: some View {
    VStack {
      Ellipse()
        .stroke(hasDetectedValidFace ? Color.green : Color.red)
        .frame(width: layoutGuideFrame.width, height: layoutGuideFrame.height)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    FaceVerificationView(model: CameraViewModel())
  }
}
