import Foundation
import SwiftUI // For UIImage
import Combine // For Cancellable - Can likely remove if not used elsewhere now

/// Represents the purpose of the image capture action.
enum CaptureMode {
    case enroll
    case verify
}

/// Manages the state and logic for the face recognition UI.
@MainActor // Ensure UI updates happen on the main thread
class ContentViewModel: ObservableObject {

    // MARK: - Published Properties (UI State)
    @Published var enrolledImage: UIImage? = nil
    @Published var isEnrolled: Bool = false
    @Published var verificationStatus: VerificationStatus = .idle
    @Published var isProcessing: Bool = false // Used for DeepLook/Storage processing
    @Published var errorMessage: String? = nil
    @Published var showSettings: Bool = false // To present settings view/modal

    // State for controlling the capture sheet
    @Published var showCaptureSheet: Bool = false
    @Published var currentCaptureMode: CaptureMode = .enroll // Default

    @AppStorage("similarityThreshold") var similarityThreshold: Double = 0.8 // Default threshold

    // MARK: - Services
    private let storageService: StorageManaging
    private let deepLookService: FaceVerificationProviding
    // Camera Service is still owned here but passed down
    @StateObject var cameraService: CameraService

    // MARK: - Initialization
    init(
        storageService: StorageManaging = StorageService(),
        deepLookService: FaceVerificationProviding = DeepLookService(),
        cameraService: CameraOperating = CameraService() // Allow injecting for tests
    ) {
        self.storageService = storageService
        self.deepLookService = deepLookService
        guard let concreteCameraService = cameraService as? CameraService else {
             fatalError("CameraService must be the concrete CameraService class for @StateObject")
         }
         _cameraService = StateObject(wrappedValue: concreteCameraService)

        loadInitialState()
        // Removed setupBindings() for camera image/error, as CaptureView handles it
    }

    // MARK: - Public Methods (User Actions)

    /// Prepares for enrollment capture by showing the capture sheet.
    func enrollButtonTapped() {
        guard !isProcessing else { return }
        clearError()
        currentCaptureMode = .enroll
        showCaptureSheet = true // Trigger sheet presentation
    }

    /// Prepares for verification capture by showing the capture sheet.
    func verifyButtonTapped() {
        guard isEnrolled, !isProcessing else {
             if !isEnrolled {
                 setError("Please enroll a face first.")
             }
             return
        }
        clearError()
        currentCaptureMode = .verify
        showCaptureSheet = true // Trigger sheet presentation
    }

    /// Handles the result coming back from the CaptureView.
    /// - Parameters:
    ///   - image: The captured UIImage, or nil if cancelled/failed.
    ///   - mode: The mode (.enroll or .verify) the capture was initiated for.
    func handleCaptureCompletion(image: UIImage?, mode: CaptureMode) {
        showCaptureSheet = false // Dismiss the sheet regardless of outcome

        guard let capturedImage = image else {
            setError("Capture cancelled or failed.")
            setStatus(.idle) // Reset status if capture didn't complete
            return
        }

        // Set status and processing flag based on mode
        setStatus(mode == .enroll ? .enrolling : .verifying) // Show processing status

        // Process the captured image based on the mode
        switch mode {
        case .enroll:
            processEnrollment(image: capturedImage)
        case .verify:
            processVerification(image: capturedImage)
        }
    }


    /// Deletes the currently enrolled face.
    func deleteEnrollment() {
        guard !isProcessing else { return }
        isProcessing = true // Indicate processing storage
        Task { // Perform deletion off main thread
            do {
                try storageService.deleteEnrolledImage()
                // Update UI back on main thread
                await MainActor.run {
                    self.enrolledImage = nil
                    self.isEnrolled = false
                    self.setStatus(.idle)
                    self.isProcessing = false
                    print("Enrollment deleted.")
                }
            } catch {
                await MainActor.run {
                    self.setError("Failed to delete enrollment: \(error.localizedDescription)")
                    self.isProcessing = false
                }
            }
        }
    }

    /// Called when the ContentView appears. Loads initial state.
    func onAppear() {
         loadInitialState() // Load enrollment status etc. (No camera start here)
         // Permission request could be moved to CaptureView's onAppear if preferred
         // Or kept here to request upfront. Let's keep it here for now.
         Task {
             let granted = await cameraService.requestPermission()
             if !granted {
                 setError("Camera permission denied. Please enable it in Settings.")
             }
         }
     }

    /// Called when the ContentView disappears. (No camera stop here)
    func onDisappear() {
         // No action needed here for camera anymore
     }

    // MARK: - Private Helper Methods

    /// Loads the initial state (enrolled image) when the ViewModel is created or view appears.
    private func loadInitialState() {
        if let loadedImage = storageService.loadEnrolledImage() {
            if self.enrolledImage == nil { // Avoid reloading if already loaded
                 self.enrolledImage = loadedImage
                 self.isEnrolled = true
                 print("Loaded existing enrollment.")
            }
        } else {
            self.enrolledImage = nil
            self.isEnrolled = false
            // print("No existing enrollment found.") // Reduce console noise
        }
         // Ensure status is idle if not processing
         if !isProcessing {
             setStatus(.idle)
         }
    }

    /// Handles the logic *after* an image is captured for enrollment.
    private func processEnrollment(image: UIImage) {
        Task { // Perform storage I/O off main thread
             do {
                 try storageService.saveEnrolledImage(image)
                 // Update UI state back on the main thread
                 await MainActor.run {
                    self.enrolledImage = image
                    self.isEnrolled = true
                    self.setStatus(.enrollmentSuccess)
                    print("Enrollment successful.")
                 }
             } catch {
                 // Update UI state back on the main thread
                 await MainActor.run {
                    self.setError("Enrollment failed: \(error.localizedDescription)")
                    self.resetProcessingState()
                 }
             }
        }
    }

    /// Handles the logic *after* an image is captured for verification.
    private func processVerification(image: UIImage) {
        guard let enrolled = self.enrolledImage else {
            setError("Cannot verify, no face is enrolled.")
            resetProcessingState()
            return
        }

        Task { // Perform DeepLook comparison off the main thread
            let result = await deepLookService.compareFaces(image1: enrolled, image2: image)

            // Update UI state back on the main thread
            await MainActor.run {
                switch result {
                case .success(let similarity):
                    let isMatch = similarity >= Float(self.similarityThreshold)
                    self.setStatus(isMatch ? .matchFound(similarity) : .noMatchFound(similarity))
                    print("Verification complete. Similarity: \(similarity), Threshold: \(self.similarityThreshold), Match: \(isMatch)")

                case .failure(let deepLookError):
                    self.setError("Verification failed: \(deepLookError.localizedDescription)")
                    self.setStatus(.verificationFailed)
                }
            }
        }
    }

    // MARK: - Status & Error Management (mostly unchanged)

    private func setStatus(_ newStatus: VerificationStatus) {
        verificationStatus = newStatus
        // Manage isProcessing based on status transitions involving DeepLook/Storage
        switch newStatus {
        case .enrolling, .verifying:
            isProcessing = true // Indicates DeepLook/Storage work is starting
        case .idle, .enrollmentSuccess, .matchFound, .noMatchFound, .verificationFailed:
            isProcessing = false // Indicates DeepLook/Storage work is done or failed
        }
    }

    private func setError(_ message: String) {
        print("Error Set: \(message)")
        errorMessage = message
        isProcessing = false // Stop processing on error
    }

    private func clearError() {
        if errorMessage != nil {
            errorMessage = nil
        }
    }

    private func resetProcessingState() {
         isProcessing = false
         // Only reset status if it was actively processing
         if verificationStatus == .enrolling || verificationStatus == .verifying {
              setStatus(.idle)
         }
     }

    // MARK: - Status Enum (Unchanged)
    enum VerificationStatus: Equatable {
        case idle
        case enrolling // Now means "Processing enrollment after capture"
        case verifying // Now means "Processing verification after capture"
        case enrollmentSuccess
        case matchFound(Float)
        case noMatchFound(Float)
        case verificationFailed

        var description: String {
            switch self {
            case .idle: return "Ready"
            case .enrolling: return "Processing Enrollment..." // Updated text
            case .verifying: return "Processing Verification..." // Updated text
            case .enrollmentSuccess: return "Enrollment Successful!"
            case .matchFound(let score): return String(format: "Match Found (Score: %.2f)", score)
            case .noMatchFound(let score): return String(format: "No Match (Score: %.2f)", score)
            case .verificationFailed: return "Verification Failed"
            }
        }
    }
}