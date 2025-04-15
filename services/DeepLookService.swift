import Foundation
import DeepLook // Import the DeepLook framework
import UIKit

/// Protocol defining the face verification operations using DeepLook.
protocol FaceVerificationProviding {
    /// Compares two images to determine if they contain the same face.
    /// - Parameters:
    ///   - image1: The first UIImage.
    ///   - image2: The second UIImage.
    /// - Returns: A Result containing a tuple (isSamePerson: Bool, similarity: Float) on success,
    ///            or a DeepLookError on failure.
    func compareFaces(image1: UIImage, image2: UIImage) async -> Result<(similarity: Float), DeepLookError>
}

/// Service class responsible for interacting with the DeepLook SDK for face verification.
class DeepLookService: FaceVerificationProviding {

    /// Static instance of DeepLook configured for face operations.
    /// Configuration can be adjusted here if needed (e.g., model type).
    /// This assumes DeepLook() constructor initializes necessary components.
    /// Check DeepLook documentation for specific initialization requirements.
    private let deepLook: DeepLook

    init() {
        // Initialize DeepLook. Add configuration options if necessary based on SDK docs.
        // Example: let config = DeepLook.Configuration(...)
        // self.deepLook = DeepLook(configuration: config)
        self.deepLook = DeepLook() // Assuming default initializer works
        print("DeepLook Service Initialized")
    }

    /// Compares two UIImages using the DeepLook SDK.
    /// This function encapsulates the detect, align, represent, and verify pipeline stages.
    /// - Parameters:
    ///   - image1: The first UIImage (e.g., the enrolled image).
    ///   - image2: The second UIImage (e.g., the newly captured image).
    /// - Returns: An asynchronous Result containing the similarity score on success, or a DeepLookError on failure.
    func compareFaces(image1: UIImage, image2: UIImage) async -> Result<Float, DeepLookError> {
        print("DeepLookService: Starting face comparison.")
        do {
            // DeepLook's `compare` function handles the entire pipeline:
            // 1. Detect: Finds faces in both images.
            // 2. Align: Normalizes face orientation and scale.
            // 3. Represent: Creates a feature vector (embedding) for each face.
            // 4. Verify: Calculates the similarity between the embeddings.
            let result = try await deepLook.compare(image1: image1, image2: image2)

            // Handle potential outcomes based on DeepLook documentation:
            switch result.status {
            case .ok:
                guard let similarity = result.similarity else {
                    print("DeepLookService Error: Status OK but similarity is nil.")
                    return .failure(.unexpectedResult("Status OK but similarity is nil."))
                }
                print("DeepLookService: Comparison successful. Similarity: \(similarity)")
                return .success(similarity)

            case .noFaceFound:
                print("DeepLookService Error: No face found in one or both images.")
                return .failure(.noFaceFound)

            case .multipleFacesFound:
                print("DeepLookService Error: Multiple faces found in one or both images.")
                return .failure(.multipleFacesFound)

            case .fail:
                let errorMessage = result.error?.localizedDescription ?? "Unknown DeepLook processing error."
                print("DeepLookService Error: Processing failed. \(errorMessage)")
                return .failure(.processingFailed(errorMessage))

            // Add other potential cases from DeepLook.Status if they exist
            @unknown default:
                print("DeepLookService Error: Unknown status received from DeepLook.")
                return .failure(.unknownError("Unknown status"))
            }
        } catch let error as DeepLook.Error {
            // Catch specific DeepLook errors if they are thrown directly
             print("DeepLookService Error: Caught DeepLook specific error - \(error.localizedDescription)")
             // Map DeepLook.Error cases to your DeepLookError enum if needed
             return .failure(.sdkError(error))
        } catch {
            // Catch any other unexpected errors during the async call
            print("DeepLookService Error: Unexpected error during comparison - \(error.localizedDescription)")
            return .failure(.unknownError(error.localizedDescription))
        }
    }
}

/// Custom errors related to DeepLook operations.
enum DeepLookError: Error, LocalizedError {
    case sdkInitializationFailed(String)
    case noFaceFound
    case multipleFacesFound
    case processingFailed(String)
    case unexpectedResult(String)
    case sdkError(DeepLook.Error) // To wrap specific DeepLook errors
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .sdkInitializationFailed(let reason):
            return "Failed to initialize DeepLook SDK: \(reason)"
        case .noFaceFound:
            return "No face was detected in one or both images."
        case .multipleFacesFound:
            return "Multiple faces were detected. Please ensure only one face is present."
        case .processingFailed(let reason):
            return "DeepLook failed to process the image(s): \(reason)"
        case .unexpectedResult(let reason):
            return "Received an unexpected result from DeepLook: \(reason)"
        case .sdkError(let error):
             return "DeepLook SDK error: \(error.localizedDescription)" // Or provide more specific descriptions based on DeepLook.Error cases
        case .unknownError(let reason):
            return "An unknown error occurred: \(reason)"
        }
    }
}