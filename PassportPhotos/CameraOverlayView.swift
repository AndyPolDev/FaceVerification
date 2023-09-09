

import SwiftUI

struct CameraOverlayView: View {
  @ObservedObject private(set) var model: CameraViewModel
  
  var body: some View {
    GeometryReader { geometry in
      VStack {
        CameraControlsHeaderView(model: model)
        Spacer()
          .frame(height: geometry.size.width * 1)
        CameraControlsFooterView(model: model)
      }
    }
  }
}

struct CameraControlsHeaderView: View {
  @ObservedObject var model: CameraViewModel
  
  var body: some View {
    ZStack {
      Rectangle()
        .fill(Color.clear)
      UserInstructionsView(model: model)
    }
  }
}

struct UserInstructionsView: View {
  @ObservedObject var model: CameraViewModel
  
  var body: some View {
    Text(faceDetectionStateLabel())
      .font(.title)
      .foregroundColor(.white)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .multilineTextAlignment(.center)
  }
  
  private func faceDetectionStateLabel() -> String {
    switch model.faceDetectedState {
    case .faceDetectionErrored:
      return "Ошибка распознавания лица"
    case .noFaceDetected:
      return "Пожалуйста, смотрите в камеру"
    case .faceDetected:
      if model.hasDetectedValidFace && model.userCanSmile && model.success {
        return "Успех!"
      } else if model.hasDetectedValidFace && model.userCanSmile {
        return "Пожалуйста улыбнитесь"
      } else if model.hasDetectedValidFace {
        return "Обнаружено лицо, оставайтесь в рамке..."
      } else if model.isAcceptableBounds == .detectedFaceTooSmall {
        return "Пожалуйста, приблизьте лицо к камере"
      } else if model.isAcceptableBounds == .detectedFaceTooLarge {
        return "Пожалуйста, держите камеру подальше от лица"
      } else if model.isAcceptableBounds == .detectedFaceOffCentre {
        return "Пожалуйста, держите лицо в центр рамки"
      } else if !model.isAcceptableRoll || !model.isAcceptablePitch || !model.isAcceptableYaw {
        return "Пожалуйста, смотрите прямо в камеру"
      } else if !model.isAcceptableQuality {
        return "Слишком низкое качество изображения"
      } else {
        return "Ошибка распознавания лица"
      }
    }
  }
}


struct CameraControlsFooterView: View {
  @ObservedObject var model: CameraViewModel
  
  var body: some View {
    ZStack {
      Rectangle()
        .fill(LinearGradient(
          gradient: Gradient(colors: [Color.clear, Color.yellow]),
          startPoint: .top,
          endPoint: .bottom
        ))
      CameraControlsView(model: model)
    }
  }
  
  struct CameraControlsView: View {
    @ObservedObject var model: CameraViewModel
    
    var body: some View {
      HStack() {
        Spacer()
        DebugButton(isDebugEnabled: model.debugModeEnabled) {
          model.perform(action: .toggleDebugMode)
        }
        Spacer()
      }
    }
  }
  
  struct DebugButton: View {
    let isDebugEnabled: Bool
    let action: (() -> Void)
    
    var body: some View {
      Button(action: {
        action()
      }, label: {
        Image(systemName: "camera.aperture")
          .font(.system(size: 40))
      })
      .tint(isDebugEnabled ? .red : .gray)
    }
  }
}

struct CameraControlsView_Previews: PreviewProvider {
  static var previews: some View {
    CameraOverlayView(model: CameraViewModel())
  }
}
