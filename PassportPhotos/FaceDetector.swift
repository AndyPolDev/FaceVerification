import AVFoundation
import CoreImage.CIFilterBuiltins
import UIKit
import Vision
import VideoToolbox

protocol FaceDetectorDelegate: NSObjectProtocol {
  func convertFromMetadataToPreviewRect(rect: CGRect) -> CGRect
  func draw(image: CIImage)
}

final class FaceDetector: NSObject {
  weak var viewDelegate: FaceDetectorDelegate?
  weak var model: CameraViewModel?

  var sequenceHandler = VNSequenceRequestHandler()
  var currentFrameBuffer: CVImageBuffer?

  let imageProcessingQueue = DispatchQueue(
    label: "Image Processing Queue",
    qos: .userInitiated,
    attributes: [],
    autoreleaseFrequency: .workItem
  )
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods

extension FaceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }

    let detectFaceRectanglesRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFaceRectangles)
    detectFaceRectanglesRequest.revision = VNDetectFaceRectanglesRequestRevision3
    
    let detectCaptureQualityRequest = VNDetectFaceCaptureQualityRequest(completionHandler: detectedFaceQualityRequest)
    detectCaptureQualityRequest.revision = VNDetectFaceCaptureQualityRequestRevision2
    
    self.detectSmileOn(buffer: imageBuffer)
    
    currentFrameBuffer = imageBuffer
    do {
      try sequenceHandler.perform(
        [detectFaceRectanglesRequest, detectCaptureQualityRequest],
        on: imageBuffer,
        orientation: .leftMirrored)
    } catch {
      print(error.localizedDescription)
    }
  }
}

// MARK: - Private methods

extension FaceDetector {
  func detectedFaceRectangles(request: VNRequest, error: Error?) {
    guard let model = model, let viewDelegate = viewDelegate else {
      return
    }

    guard
      let results = request.results as? [VNFaceObservation],
      let result = results.first
    else {
      model.perform(action: .noFaceDetected)
      return
    }

    let convertedBoundingBox =
      viewDelegate.convertFromMetadataToPreviewRect(rect: result.boundingBox)

    let faceObservationModel = FaceGeometryModel(
      boundingBox: convertedBoundingBox,
      roll: result.roll ?? 0,
      pitch: result.pitch ?? 0,
      yaw: result.yaw ?? 0
    )

    model.perform(action: .faceObservationDetected(faceObservationModel))
  }

  func detectedFaceQualityRequest(request: VNRequest, error: Error?) {
    guard let model = model else { return }
    
    guard let results = request.results as? [VNFaceObservation], let result = results.first else {
      model.perform(action: .noFaceDetected)
      return
    }
    
    let faceQualityModel = FaceQualityModel(quality: result.faceCaptureQuality ?? 0)
     
    model.perform(action: .faceQualityObservationDetected(faceQualityModel))
  }
  
  func detectSmileOn(buffer: CVPixelBuffer) {
    guard let model = model else { return }
      if let inputImage = UIImage(pixelBuffer: buffer) {
          let ciImage = CIImage(cgImage: inputImage.cgImage!)
          
          let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
          let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: options)!
          let smileDetector = faceDetector.features(
              in: ciImage,
              options: [CIDetectorSmile: true]) as? [CIFaceFeature]
          
          if let face = smileDetector?.first as? CIFaceFeature {
            let faceSmileModel = FaceSmileModel(smileDetected: face.hasSmile)
            model.perform(action: .faceSmaileObservationDetected(faceSmileModel))
          }
      }
  }
}


extension UIImage {
  
  public convenience init?(pixelBuffer: CVPixelBuffer) {
    var cgImage: CGImage?
    VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
    
    guard let cgIm = cgImage else {
      return nil
    }
    
    self.init(cgImage: cgIm)
  }
}
