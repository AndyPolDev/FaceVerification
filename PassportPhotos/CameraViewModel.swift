//Этот класс CameraViewModel предоставляет высокоуровневую логику и состояние для работы с камерой и детектированием лиц. В основном, он отвечает за обработку и анализ входящих данных от камеры, а также уведомляет пользовательский интерфейс о любых изменениях состояния.


import Combine
import CoreGraphics
import UIKit
import Vision

enum CameraViewModelAction {
  // View setup and configuration actions
  case windowSizeDetected(CGRect)
  
  // Face detection actions
  case noFaceDetected
  case faceObservationDetected(FaceGeometryModel)
  case faceQualityObservationDetected(FaceQualityModel)
  case faceSmaileObservationDetected(FaceSmileModel)
  
  // Other
  case toggleDebugMode
}

enum FaceDetectedState {
  case faceDetected
  case noFaceDetected
  case faceDetectionErrored
}

enum FaceBoundsState {
  case unknown
  case detectedFaceTooSmall
  case detectedFaceTooLarge
  case detectedFaceOffCentre
  case detectedFaceAppropriateSizeAndPosition
}

struct FaceGeometryModel {
  let boundingBox: CGRect
  let roll: NSNumber
  let pitch: NSNumber
  let yaw: NSNumber
}

struct FaceQualityModel {
  let quality: Float
}

struct FaceSmileModel {
  let smileDetected: Bool
}

final class CameraViewModel: ObservableObject {
  // MARK: - Publishers
  @Published var debugModeEnabled: Bool
  
  // MARK: - Publishers of derived state
  @Published private(set) var hasDetectedValidFace: Bool
  
  @Published private(set) var userCanSmile: Bool
  @Published private(set) var success: Bool
  
  @Published private(set) var hasDetectedSmile: Bool {
    didSet {
      handleSmile()
    }
  }
  @Published private(set) var isAcceptableRoll: Bool {
    didSet {
      calculateDetectedFaceValidity()
    }
  }
  @Published private(set) var isAcceptablePitch: Bool {
    didSet {
      calculateDetectedFaceValidity()
    }
  }
  @Published private(set) var isAcceptableYaw: Bool {
    didSet {
      calculateDetectedFaceValidity()
    }
  }
  @Published private(set) var isAcceptableBounds: FaceBoundsState {
    didSet {
      calculateDetectedFaceValidity()
    }
  }
  @Published private(set) var isAcceptableQuality: Bool {
    didSet {
      calculateDetectedFaceValidity()
    }
  }
  
  // MARK: - Publishers of Vision data directly
  @Published private(set) var faceDetectedState: FaceDetectedState
  @Published private(set) var faceGeometryState: FaceObservation<FaceGeometryModel> {
    didSet {
      processUpdatedFaceGeometry()
    }
  }
  
  @Published private(set) var faceQualityState: FaceObservation<FaceQualityModel> {
    didSet {
      processUpdatedFaceQuality()
    }
  }
  
  @Published private(set) var faceSmileState: FaceObservation<FaceSmileModel> {
    didSet {
      processUpdatedFaceSmile()
    }
  }
  
  var faceDetectionTimer: Timer?
  
  // MARK: - Public properties
  let shutterReleased = PassthroughSubject<Void, Never>()
  
  // MARK: - Private variables
  var faceLayoutGuideFrame = CGRect(x: 0, y: 0, width: 200, height: 300)
  
  init() {
    faceDetectedState = .noFaceDetected
    
    hasDetectedValidFace = false
    hasDetectedSmile = false
    faceGeometryState = .faceNotFound
    
#if DEBUG
    debugModeEnabled = true
#else
    debugModeEnabled = false
#endif
    isAcceptableRoll = false
    isAcceptablePitch = false
    isAcceptableYaw = false
    isAcceptableBounds = .unknown
    faceQualityState = .faceNotFound
    isAcceptableQuality = false
    faceSmileState = .faceNotFound
    userCanSmile = false
    success = false
  }
  
  // MARK: Actions
  func perform(action: CameraViewModelAction) {
    switch action {
    case .windowSizeDetected(let windowRect):
      handleWindowSizeChanged(toRect: windowRect)
    case .noFaceDetected:
      publishNoFaceObserved()
    case .faceObservationDetected(let faceObservation):
      publishFaceObservation(faceObservation)
    case .toggleDebugMode:
      toggleDebugMode()
    case .faceQualityObservationDetected(let faceQualityObservation):
      publishFaceQualityObservation(faceQualityObservation)
    case .faceSmaileObservationDetected(let faceSmaileObservation):
      publishFaceSmileObservation(faceSmaileObservation)
    }
  }
  
  // MARK: Action handlers
  
  private func handleWindowSizeChanged(toRect: CGRect) {
    faceLayoutGuideFrame = CGRect(
      x: toRect.midX - faceLayoutGuideFrame.width / 2,
      y: toRect.midY - faceLayoutGuideFrame.height / 2,
      width: faceLayoutGuideFrame.width,
      height: faceLayoutGuideFrame.height
    )
  }
  
  private func publishNoFaceObserved() {
    DispatchQueue.main.async { [self] in
      faceDetectedState = .noFaceDetected
      faceGeometryState = .faceNotFound
    }
  }
  
  private func publishFaceObservation(_ faceGeometryModel: FaceGeometryModel) {
    DispatchQueue.main.async { [self] in
      
      faceDetectedState = .faceDetected
      
      faceGeometryState = .faceFound(faceGeometryModel)
    }
  }
  
  private func publishFaceQualityObservation(_ faceQualityModel: FaceQualityModel) {
    DispatchQueue.main.async { [self] in
      
      faceDetectedState = .faceDetected
      
      faceQualityState = .faceFound(faceQualityModel)
    }
  }
  
  private func publishFaceSmileObservation(_ faceSmileModel: FaceSmileModel) {
    DispatchQueue.main.async { [self] in
      
      faceDetectedState = .faceDetected
      
      faceSmileState = .faceFound(faceSmileModel)
    }
  }
  
  private func toggleDebugMode() {
    debugModeEnabled.toggle()
  }
}

// MARK: Private instance methods

extension CameraViewModel {
  func invalidateFaceGeometryState() {
    isAcceptableRoll = false
    isAcceptablePitch = false
    isAcceptableYaw = false
    isAcceptableBounds = .unknown
  }
  
  func processUpdatedFaceGeometry() {
    switch faceGeometryState {
    case .faceNotFound:
      invalidateFaceGeometryState()
    case .errored(let error):
      print(error.localizedDescription)
      invalidateFaceGeometryState()
    case .faceFound(let faceGeometryModel):
      let roll = faceGeometryModel.roll.doubleValue
      let pitch = faceGeometryModel.pitch.doubleValue
      let yaw = faceGeometryModel.yaw.doubleValue
      updateAcceptableRollPitchYaw(using: roll, pitch: pitch, yaw: yaw)
      let boundingBox = faceGeometryModel.boundingBox
      updateAcceptableBounds(using: boundingBox)
      return
    }
  }
  
  func updateAcceptableBounds(using boundingBox: CGRect) {
    if boundingBox.width > 1.2 * faceLayoutGuideFrame.width {
      isAcceptableBounds = .detectedFaceTooLarge
    } else if boundingBox.width * 1.2 < faceLayoutGuideFrame.width {
      isAcceptableBounds = .detectedFaceTooSmall
    } else {
      if abs(boundingBox.midX - faceLayoutGuideFrame.midX) > 50 {
        isAcceptableBounds = .detectedFaceOffCentre
      } else if abs(boundingBox.midY - faceLayoutGuideFrame.midY) > 50 {
        isAcceptableBounds = .detectedFaceOffCentre
      } else {
        isAcceptableBounds = .detectedFaceAppropriateSizeAndPosition
      }
    }
  }
  
  func updateAcceptableRollPitchYaw(using roll: Double, pitch: Double, yaw: Double) {
    isAcceptableRoll = (roll > 1.2 && roll < 1.6)
    isAcceptablePitch = abs(CGFloat(pitch)) < 0.2
    isAcceptableYaw = abs(CGFloat(yaw)) < 0.15
  }
  
  func processUpdatedFaceQuality() {
    switch faceQualityState {
    case .faceNotFound:
      isAcceptableQuality = false
    case .errored(let error):
      print(error.localizedDescription)
      isAcceptableQuality = false
    case .faceFound(let faceQualityModel):
      if faceQualityModel.quality < 0.2 {
        isAcceptableQuality = false
      }
      isAcceptableQuality = true
    }
  }
  
  func processUpdatedFaceSmile() {
    if hasDetectedValidFace {
      switch faceSmileState {
      case .faceFound(let faceSmileModel):
        print("@ faceSmileModel - \(faceSmileModel)")
        hasDetectedSmile = faceSmileModel.smileDetected
      case .faceNotFound:
        hasDetectedSmile = false
      case .errored(let error):
        print(error.localizedDescription)
        hasDetectedSmile = false
      }
    }
  }
  
  func calculateDetectedFaceValidity() {
    let previouslyValid = hasDetectedValidFace
    
    hasDetectedValidFace =
    isAcceptableBounds == .detectedFaceAppropriateSizeAndPosition &&
    isAcceptableRoll &&
    isAcceptablePitch &&
    isAcceptableYaw &&
    isAcceptableQuality
    
    if !previouslyValid && hasDetectedValidFace {
      startFaceDetectionTimer()
    } else if previouslyValid && !hasDetectedValidFace {
      cancelFaceDetectionTimer()
    }
  }
  
  func startFaceDetectionTimer() {
    guard faceDetectionTimer == nil else { return }
    faceDetectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] timer in
      self?.userCanSmile = true
    }
  }
  
  func cancelFaceDetectionTimer() {
    faceDetectionTimer?.invalidate()
    faceDetectionTimer = nil
    userCanSmile = false
  }
  
  func handleSmile() {
    if hasDetectedValidFace, userCanSmile {
      if hasDetectedSmile {
        success = true
      } else {
        success = false
      }
    }
  }
}
