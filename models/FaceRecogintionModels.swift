import Foundation
import Vision

/// Represents a stored face with its feature print observation
struct StoredFace: Identifiable, Codable {
    let id: UUID
    let name: String
    let featurePrintData: Data
    let dateAdded: Date
    
    init(id: UUID = UUID(), name: String, featurePrintData: Data, dateAdded: Date = Date()) {
        self.id = id
        self.name = name
        self.featurePrintData = featurePrintData
        self.dateAdded = dateAdded
    }
}

/// Represents the result of a face verification
enum VerificationResult {
    case match(StoredFace, Float)
    case noMatch
    case error(Error)
}

/// Represents errors that can occur during face operations
enum FaceRecognitionError: Error {
    case noFaceDetected
    case multipleFacesDetected
    case failedToGenerateFeaturePrint
    case failedToConvertObservation
    case cameraUnavailable
    case processingError(String)
}

/// Represents the current state of the app
enum AppState {
    case idle
    case capturing
    case processing
    case enrolling
    case verifying
    case results(VerificationResult)
}