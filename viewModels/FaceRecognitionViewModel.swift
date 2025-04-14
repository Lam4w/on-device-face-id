import Foundation
import SwiftUI
import UIKit
import AVFoundation

/// ViewModel that coordinates between UI, Vision, and Storage services
class FaceRecognitionViewModel: ObservableObject {
    /// Camera service for capturing images
    private let cameraService = CameraService()
    
    /// Vision service for face detection and feature print generation
    private let visionService: VisionService
    
    /// Storage service for persisting face data
    private let storageService = StorageService()
    
    /// Current app state
    @Published var appState: AppState = .idle
    
    /// Preview image from camera
    @Published var previewImage: UIImage?
    
    /// Name for enrolling a new face
    @Published var enrollName: String = ""
    
    /// Current verification result
    @Published var verificationResult: VerificationResult?
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// List of stored faces
    var storedFaces: [StoredFace] {
        storageService.storedFaces
    }
    
    /// Current similarity threshold
    @Published var similarityThreshold: Float {
        didSet {
            visionService.updateSimilarityThreshold(similarityThreshold)
            UserDefaults.standard.set(similarityThreshold, forKey: "similarity_threshold")
        }
    }
    
    init() {
        // Load saved threshold or use default
        let savedThreshold = UserDefaults.standard.float(forKey: "similarity_threshold")
        let threshold = savedThreshold > 0 ? savedThreshold : 0.7
        self.similarityThreshold = threshold
        self.visionService = VisionService(similarityThreshold: threshold)
        
        // Set up camera callback
        cameraService.captureCallback = { [weak self] image in
            DispatchQueue.main.async {
                self?.previewImage = image
            }
        }
    }
    
    /// Starts the camera preview
    func startCamera() {
        Task {
            do {
                try await cameraService.start()
            } catch {
                await setError(error.localizedDescription)
            }
        }
    }
    
    /// Stops the camera preview
    func stopCamera() {
        cameraService.stop()
    }
    
    /// Captures an image for enrollment
    func captureForEnrollment() {
        captureImage { [weak self] image in
            guard let self = self else { return }
            self.appState = .enrolling
            self.processForEnrollment(image: image)
        }
    }
    
    /// Captures an image for verification
    func captureForVerification() {
        captureImage { [weak self] image in
            guard let self = self else { return }
            self.appState = .verifying
            self.processForVerification(image: image)
        }
    }
    
    /// Captures a still image from the camera
    /// - Parameter completion: Callback with the captured UIImage
    private func captureImage(completion: @escaping (UIImage) -> Void) {
        appState = .capturing
        cameraService.captureStillImage { result in
            DispatchQueue.main.async { [weak self] in
                switch result {
                case .success(let image):
                    completion(image)
                case .failure(let error):
                    self?.appState = .idle
                    self?.setError("Failed to capture image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Processes a captured image for face enrollment
    /// - Parameter image: Image to process
    private func processForEnrollment(image: UIImage) {
        guard !enrollName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setError("Please enter a name for this face")
            appState = .idle
            return
        }
        
        appState = .processing
        
        Task {
            do {
                // Detect face
                let faceObservations = try await visionService.detectFaces(in: image)
                
                if faceObservations.count > 1 {
                    throw FaceRecognitionError.multipleFacesDetected
                }
                
                guard let faceObservation = faceObservations.first else {
                    throw FaceRecognitionError.noFaceDetected
                }
                
                // Crop to face
                let croppedImage = try visionService.cropToFace(image: image, observation: faceObservation)
                
                // Generate feature print
                let featurePrint = try await visionService.generateFeaturePrint(for: croppedImage)
                
                // Convert to Data
                let featurePrintData = try visionService.serializeFeaturePrint(featurePrint)
                
                // Store face
                let storedFace = storageService.storeFace(name: enrollName, featurePrintData: featurePrintData)
                
                await MainActor.run {
                    enrollName = ""
                    appState = .idle
                    setSuccess("Successfully enrolled \(storedFace.name)")
                }
            } catch {
                await handleError(error)
            }
        }
    }
    
    /// Processes a captured image for face verification
    /// - Parameter image: Image to process
    private func processForVerification(image: UIImage) {
        guard !storedFaces.isEmpty else {
            setError("No faces enrolled yet")
            appState = .idle
            return
        }
        
        appState = .processing
        
        Task {
            do {
                // Detect face
                let faceObservations = try await visionService.detectFaces(in: image)
                
                if faceObservations.count > 1 {
                    throw FaceRecognitionError.multipleFacesDetected
                }
                
                guard let faceObservation = faceObservations.first else {
                    throw FaceRecognitionError.noFaceDetected
                }
                
                // Crop to face
                let croppedImage = try visionService.cropToFace(image: image, observation: faceObservation)
                
                // Generate feature print
                let featurePrint = try await visionService.generateFeaturePrint(for: croppedImage)
                
                // Compare with stored faces
                let result = try visionService.compareWithStoredFaces(featurePrint: featurePrint, storedFaces: storedFaces)
                
                await MainActor.run {
                    verificationResult = result
                    appState = .results(result)
                }
            } catch {
                await handleError(error)
            }
        }
    }
    
    /// Handles errors from face processing
    /// - Parameter error: Error to handle
    @MainActor
    private func handleError(_ error: Error) {
        appState = .idle
        
        if let faceError = error as? FaceRecognitionError {
            switch faceError {
            case .noFaceDetected:
                setError("No face detected in the image")
            case .multipleFacesDetected:
                setError("Multiple faces detected. Please ensure only one face is in the frame")
            case .failedToGenerateFeaturePrint:
                setError("Failed to analyze facial features")
            case .failedToConvertObservation:
                setError("Failed to process facial data")
            case .cameraUnavailable:
                setError("Camera is unavailable")
            case .processingError(let message):
                setError("Processing error: \(message)")
            }
        } else {
            setError("Error: \(error.localizedDescription)")
        }
    }
    
    /// Sets an error message to display
    /// - Parameter message: Error message
    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
        
        // Auto-clear error after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.errorMessage = nil
        }
    }
    
    /// Sets a success message to display
    /// - Parameter message: Success message
    @MainActor
    private func setSuccess(_ message: String) {
        // For now, use the error message field for success messages too
        errorMessage = message
        
        // Auto-clear after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.errorMessage = nil
        }
    }
    
    /// Removes a stored face
    /// - Parameter id: ID of the face to remove
    func removeFace(id: UUID) {
        storageService.removeFace(id: id)
    }
    
    /// Resets the view model to idle state
    func reset() {
        appState = .idle
        verificationResult = nil
    }
}