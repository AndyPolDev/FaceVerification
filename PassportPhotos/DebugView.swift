
import SwiftUI

struct DebugView: View {
  @ObservedObject var model: CameraViewModel

  var body: some View {
    ZStack {
      FaceBoundingBoxView(model: model)
      FaceLayoutGuideView(model: model)
      VStack(alignment: .leading, spacing: 5) {
        DebugSection(observation: model.faceGeometryState) { geometryModel in
          DebugText("R: \(geometryModel.roll)")
            .debugTextStatus(status: model.isAcceptableRoll ? .passing : .failing)
          DebugText("P: \(geometryModel.pitch)")
            .debugTextStatus(status: model.isAcceptablePitch ? .passing : .failing)
          DebugText("Y: \(geometryModel.yaw)")
            .debugTextStatus(status: model.isAcceptableYaw ? .passing : .failing)
        }
        DebugSection(observation: model.faceQualityState) { qualityModel in
          DebugText("Q: \(qualityModel.quality)")
            .debugTextStatus(status: model.isAcceptableQuality ? .passing : .failing)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct DebugSection<Model, Content: View>: View {
  let observation: FaceObservation<Model>
  let content: (Model) -> Content

  public init(
    observation: FaceObservation<Model>,
    @ViewBuilder content: @escaping (Model) -> Content
  ) {
    self.observation = observation
    self.content = content
  }

  var body: some View {
    switch observation {
    case .faceNotFound:
      AnyView(Spacer())
    case .faceFound(let model):
      AnyView(content(model))
    case .errored(let error):
      AnyView(
        DebugText("ERROR: \(error.localizedDescription)")
      )
    }
  }
}

enum DebugTextStatus {
  case neutral
  case failing
  case passing
}

struct DebugText: View {
  let content: String

  @inlinable
  public init(_ content: String) {
    self.content = content
  }

  var body: some View {
    Text(content)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct Status: ViewModifier {
  let foregroundColor: Color

  func body(content: Content) -> some View {
    content
      .foregroundColor(foregroundColor)
  }
}

extension DebugText {
  func colorForStatus(status: DebugTextStatus) -> Color {
    switch status {
    case .neutral:
      return .white
    case .failing:
      return .red
    case .passing:
      return .green
    }
  }

  func debugTextStatus(status: DebugTextStatus) -> some View {
    self.modifier(Status(foregroundColor: colorForStatus(status: status)))
  }
}

// FaceBoundingBoxView Отображает рамку вокруг лица

struct FaceBoundingBoxView: View {
  @ObservedObject private(set) var model: CameraViewModel

  var body: some View {
    switch model.faceGeometryState {
    case .faceNotFound:
      Rectangle().fill(Color.clear)
    case .faceFound(let faceGeometryModel):
      Rectangle()
        .path(in: CGRect(
          x: faceGeometryModel.boundingBox.origin.x,
          y: faceGeometryModel.boundingBox.origin.y,
          width: faceGeometryModel.boundingBox.width,
          height: faceGeometryModel.boundingBox.height
        ))
        .stroke(Color.yellow, lineWidth: 2.0)
    case .errored:
      Rectangle().fill(Color.clear)
    }
  }
}

// FaceLayoutGuideView — это компонент интерфейса в SwiftUI, который отображает красную рамку, базирующуюся на данных геометрии лица из модели CameraViewModel.

struct FaceLayoutGuideView: View {
  @ObservedObject private(set) var model: CameraViewModel

  var body: some View {
    Rectangle()
      .path(in: CGRect(
        x: model.faceLayoutGuideFrame.minX,
        y: model.faceLayoutGuideFrame.minY,
        width: model.faceLayoutGuideFrame.width,
        height: model.faceLayoutGuideFrame.height
      ))
      .stroke(Color.red)
  }
}

struct DebugView_Previews: PreviewProvider {
  static var previews: some View {
    DebugView(model: CameraViewModel())
  }
}
