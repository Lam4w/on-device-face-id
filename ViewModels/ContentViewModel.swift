import Foundation
import SwiftUI // For UIImage
import Combine // For Cancellable

/// Manages the state and logic for the face recognition UI.
@MainActor // Ensure UI updates happen on the main thread
class ContentViewModel: ObservableObject {

    // MARK: - Published Properties (UI State)
    @Published var enrolledImage: UIImage? = nil
    @Published var isEnrolled: Bool = false
    @Published var verificationStatus: VerificationStatus = .idle
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showSettings: Bool = false // To present settings view/modal
    @AppStorage("similarityThreshold") var similarityThreshold: Double = 0.8 // Default threshold, stored in UserDefaults

    // MARK: - Services
    private let storageService: StorageManaging
    private let deepLookService: FaceVerificationProviding
    @StateObject var cameraService: CameraService // Use StateObject here for ownership

    // MARK: - Combine Subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        storageService: StorageManaging = StorageService(),
        deepLookService: FaceVerificationProviding = DeepLookService(),
        cameraService: CameraOperating = CameraService() // Allow injecting for tests
    ) {
        self.storageService = storageService
        self.deepLookService = deepLookService
        // We need to cast cameraService back to the concrete type that conforms to ObservableObject
        // This is a bit of a workaround for using protocols with @StateObject
        guard let concreteCameraService = cameraService as? CameraService else {
             fatalError("CameraService must be the concrete CameraService class for @StateObject")
         }
         _cameraService = StateObject(wrappedValue: concreteCameraService) // Assign to the @StateObject property wrapper

        loadInitialState()
        setupBindings()
    }

    // MARK: - Public Methods (User Actions)

    /// Initiates the face enrollment process.
    func enrollButtonTapped() {
        guard !isProcessing else { return }
        clearError()
        setStatus(.enrolling)
        cameraService.capturePhoto() // Capture triggers the binding logic
    }

    /// Initiates the face verification process.
    func verifyButtonTapped() {
        guard isEnrolled, !isProcessing else {
             if !isEnrolled {
                 setError("Please enroll a face first.")
             }
             return
        }
        clearError()
        setStatus(.verifying)
        cameraService.capturePhoto() // Capture triggers the binding logic
    }

    /// Deletes the currently enrolled face.
    func deleteEnrollment() {
        guard !isProcessing else { return }
        isProcessing = true
        do {
            try storageService.deleteEnrolledImage()
            self.enrolledImage = nil
            self.isEnrolled = false
            setStatus(.idle)
            print("Enrollment deleted.")
        } catch {
            setError("Failed to delete enrollment: \(error.localizedDescription)")
        }
         isProcessing = false
    }

    /// Called when the view appears to request permissions and start camera.
    func onAppear() {
         Task {
             let granted = await cameraService.requestPermission()
             if granted {
                 cameraService.startSession()
             } else {
                 setError("Camera permission denied. Please enable it in Settings.")
                 // Optionally disable buttons or show specific UI
             }
         }
     }

    /// Called when the view disappears to stop the camera.
    func onDisappear() {
         cameraService.stopSession()
     }

    // MARK: - Private Helper Methods

    /// Loads the initial state (enrolled image) when the ViewModel is created.
    private func loadInitialState() {
        if let loadedImage = storageService.loadEnrolledImage() {
            self.enrolledImage = loadedImage
            self.isEnrolled = true
            print("Loaded existing enrollment.")
        } else {
            self.isEnrolled = false
            print("No existing enrollment found.")
        }
    }

    /// Sets up Combine pipelines to react to camera captures and errors.
    private func setupBindings() {
        // React to new photo captures from CameraService
        cameraService.$capturedImage
            .compactMap { $0 } // Ignore nil values
            .receive(on: DispatchQueue.main) // Ensure processing happens on main thread after capture
            .sink { [weak self] image in
                guard let self = self else { return }
                print("ViewModel received captured image.")
                // Decide whether to enroll or verify based on current status
                switch self.verificationStatus {
                case .enrolling:
                    self.processEnrollment(image: image)
                case .verifying:
                    self.processVerification(image: image)
                default:
                    print("Warning: Image captured but no action pending.")
                    self.isProcessing = false // Ensure processing flag is reset
                }
            }
            .store(in: &cancellables)

        // React to errors from CameraService
        cameraService.$photoCaptureError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.setError("Camera error: \(error.localizedDescription)")
                self?.resetProcessingState()
            }
            .store(in: &cancellables)
    }

    /// Handles the logic after an image is captured for enrollment.
    private func processEnrollment(image: UIImage) {
        Task { // Perform storage I/O and potential DeepLook pre-processing off main thread
             do {
                 // Optional: Pre-validate with DeepLook if needed (e.g., ensure one face)
                 // let validationResult = await deepLookService.validateFace(image: image)
                 // guard validationResult.isValid else { setError(...); return }

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
                    self.resetProcessingState() // Reset status if enroll failed
                 }
             }
        }
    }

    /// Handles the logic after an image is captured for verification.
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
                    self.setStatus(.verificationFailed) // Set specific failure status
                }
            }
        }
    }


    /// Sets the current status and manages the processing flag.
    private func setStatus(_ newStatus: VerificationStatus) {
        verificationStatus = newStatus
        // Automatically manage isProcessing based on status transitions
        switch newStatus {
        case .idle, .enrollmentSuccess, .matchFound, .noMatchFound, .verificationFailed:
            isProcessing = false
        case .enrolling, .verifying:
            isProcessing = true
        }
    }

    /// Sets an error message to be displayed to the user.
    private func setError(_ message: String) {
        print("Error Set: \(message)")
        errorMessage = message
        isProcessing = false // Stop processing on error
    }

    /// Clears any existing error messages.
    private func clearError() {
        if errorMessage != nil {
            errorMessage = nil
        }
    }

    /// Resets the processing state, usually after an error or cancellation.
     private func resetProcessingState() {
         isProcessing = false
         // Reset status to idle only if it makes sense in the context of the error
         // For example, a camera error shouldn't necessarily reset a successful enrollment status
         if verificationStatus == .enrolling || verificationStatus == .verifying {
              setStatus(.idle)
         }
     }

    // MARK: - Status Enum
    enum VerificationStatus: Equatable {
        case idle
        case enrolling
        case verifying
        case enrollmentSuccess
        case matchFound(Float)
        case noMatchFound(Float)
        case verificationFailed

        var description: String {
            switch self {
            case .idle: return "Ready"
            case .enrolling: return "Enrolling... Look at the camera."
            case .verifying: return "Verifying... Look at the camera."
            case .enrollmentSuccess: return "Enrollment Successful!"
            case .matchFound(let score): return String(format: "Match Found (Score: %.2f)", score)
            case .noMatchFound(let score): return String(format: "No Match (Score: %.2f)", score)
            case .verificationFailed: return "Verification Failed"
            }
        }
    }
}