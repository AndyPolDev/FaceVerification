import Foundation

enum FaceObservation<T> {
  case faceFound(T)
  case faceNotFound
  case errored(Error)
}
