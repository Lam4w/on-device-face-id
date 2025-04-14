import Foundation
import Vision
import UIKit
import CoreImage

/// Service responsible for all Vision framework operations
class VisionService {
    /// Default similarity threshold - lower values mean stricter matching
    private let defaultSimilarityThreshold: Float = 0.7
    
    /// Current similarity threshold used for matching
    private(set) var similarityThreshold: Float
    
    init(similarityThreshold: Float? = nil) {
        self.similarityThreshold = similarityThreshold ?? defaultSimilarityThreshold
    }
    
    /// Updates the similarity threshold
    /// - Parameter threshold: New threshold value (0.0 - 1.0)
    func updateSimilarityThreshold(_ threshold: Float) {
        similarityThreshold = max(0.0, min(1.0, threshold))
    }
    
    /// Detects faces in an image
    /// - Parameter image: UIImage to process
    /// - Returns: Array of VNFaceObservation if successful
    /// - Throws: FaceRecognitionError if no faces or multiple faces detected
    func detectFaces(in image: UIImage) async throws -> [VNFaceObservation] {
        guard let cgImage = image.cgImage else {
            throw FaceRecognitionError.processingError("Failed to get CGImage")
        }
        
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        try await withCheckedThrowingContinuation { continuation in
            do {
                try handler.perform([request])
                
                guard let observations = request.results as? [VNFaceObservation], !observations.isEmpty else {
                    continuation.resume(throwing: FaceRecognitionError.noFaceDetected)
                    return
                }
                
                continuation.resume(returning: observations)
            } catch {
                continuation.resume(throwing: FaceRecognitionError.processingError(error.localizedDescription))
            }
        }
    }
    
    /// Crops the image to the face bounding box
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - observation: VNFaceObservation containing bounding box
    /// - Returns: Cropped UIImage
    /// - Throws: FaceRecognitionError if cropping fails
    func cropToFace(image: UIImage, observation: VNFaceObservation) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw FaceRecognitionError.processingError("Failed to get CGImage")
        }
        
        // Convert normalized coordinates to pixel coordinates
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // Vision's coordinate system has (0,0) at the bottom left, UIKit has it at top left
        let x = observation.boundingBox.origin.x * width
        let y = (1 - observation.boundingBox.origin.y - observation.boundingBox.height) * height
        let faceWidth = observation.boundingBox.width * width
        let faceHeight = observation.boundingBox.height * height
        
        // Add some padding around the face (20%)
        let padding = min(faceWidth, faceHeight) * 0.2
        let cropRect = CGRect(
            x: max(0, x - padding),
            y: max(0, y - padding),
            width: min(width - x + padding, faceWidth + padding * 2),
            height: min(height - y + padding, faceHeight + padding * 2)
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            throw FaceRecognitionError.processingError("Failed to crop image")
        }
        
        return UIImage(cgImage: croppedCGImage)
    }
    
    /// Generates a feature print from a face image
    /// - Parameter image: UIImage containing a face
    /// - Returns: VNFeaturePrintObservation
    /// - Throws: FaceRecognitionError if feature print generation fails
    func generateFeaturePrint(for image: UIImage) async throws -> VNFeaturePrintObservation {
        guard let cgImage = image.cgImage else {
            throw FaceRecognitionError.processingError("Failed to get CGImage")
        }
        
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try handler.perform([request])
                
                guard let observation = request.results?.first as? VNFeaturePrintObservation else {
                    continuation.resume(throwing: FaceRecognitionError.failedToGenerateFeaturePrint)
                    return
                }
                
                continuation.resume(returning: observation)
            } catch {
                continuation.resume(throwing: FaceRecognitionError.processingError(error.localizedDescription))
            }
        }
    }
    
    /// Serializes VNFeaturePrintObservation to Data
    /// - Parameter observation: VNFeaturePrintObservation to serialize
    /// - Returns: Data representation of the observation
    /// - Throws: FaceRecognitionError if serialization fails
    func serializeFeaturePrint(_ observation: VNFeaturePrintObservation) throws -> Data {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
        } catch {
            throw FaceRecognitionError.failedToConvertObservation
        }
    }
    
    /// Deserializes Data back to VNFeaturePrintObservation
    /// - Parameter data: Data to deserialize
    /// - Returns: VNFeaturePrintObservation
    /// - Throws: FaceRecognitionError if deserialization fails
    func deserializeFeaturePrint(_ data: Data) throws -> VNFeaturePrintObservation {
        do {
            guard let observation = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self,
                from: data
            ) else {
                throw FaceRecognitionError.failedToConvertObservation
            }
            return observation
        } catch {
            throw FaceRecognitionError.failedToConvertObservation
        }
    }
    
    /// Compares a feature print with stored faces to find matches
    /// - Parameters:
    ///   - featurePrint: Feature print to compare
    ///   - storedFaces: Array of stored faces to compare against
    /// - Returns: VerificationResult indicating match or no match
    func compareWithStoredFaces(featurePrint: VNFeaturePrintObservation, storedFaces: [StoredFace]) throws -> VerificationResult {
        var bestMatch: (face: StoredFace, distance: Float)?
        
        // Find the closest match
        for storedFace in storedFaces {
            do {
                let storedFeaturePrint = try deserializeFeaturePrint(storedFace.featurePrintData)
                var distance: Float = 0
                try featurePrint.computeDistance(&distance, to: storedFeaturePrint)
                
                // Lower distance means better match
                if let currentBest = bestMatch {
                    if distance < currentBest.distance {
                        bestMatch = (storedFace, distance)
                    }
                } else {
                    bestMatch = (storedFace, distance)
                }
            } catch {
                print("Error comparing with face \(storedFace.name): \(error)")
                continue
            }
        }
        
        // Check if we have a match below threshold
        if let bestMatch = bestMatch, bestMatch.distance < similarityThreshold {
            return .match(bestMatch.face, bestMatch.distance)
        } else {
            return .noMatch
        }
    }
}