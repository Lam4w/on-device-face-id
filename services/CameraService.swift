import AVFoundation
import UIKit
import Combine // Needed for PassthroughSubject

/// Protocol defining camera operations.
protocol CameraOperating: ObservableObject {
    var capturedImage: UIImage? { get set } // Published property for captured image
    var isCameraAvailable: Bool { get }
    var previewLayer: AVCaptureVideoPreviewLayer { get }
    var photoCaptureError: Error? { get set } // Published property for errors

    func startSession()
    func stopSession()
    func capturePhoto()
    func requestPermission() async -> Bool
}

/// Manages the device camera using AVFoundation for capturing photos.
class CameraService: NSObject, CameraOperating, AVCapturePhotoCaptureDelegate {

    // MARK: - Published Properties
    @Published var capturedImage: UIImage? = nil
    @Published var photoCaptureError: Error? = nil

    // MARK: - Private Properties
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    private var currentCamera: AVCaptureDevice?
    private var isSessionRunning = false

    private var setupResult: SessionSetupResult = .success // Track setup outcome

    // MARK: - Session Setup Result Enum
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    override init() {
        super.init()
        // Defer session setup until permission is checked explicitly
        // setupSession() // REMOVE from init
        print("CameraService initialized. Session setup deferred.")
    }

    // MARK: - CameraOperating Conformance

    var isCameraAvailable: Bool {
        return frontCamera != nil || backCamera != nil
    }

    /// Provides the preview layer for display in the UI.
    var previewLayer: AVCaptureVideoPreviewLayer {
        // Return existing layer or create/configure a new one if needed
        if let layer = videoPreviewLayer {
            return layer
        } else {
            // Should ideally be configured during setupSession, return a dummy if necessary
            let dummyLayer = AVCaptureVideoPreviewLayer()
            dummyLayer.videoGravity = .resizeAspectFill
            print("Warning: Returning dummy preview layer as session wasn't fully set up.")
            return dummyLayer
        }
    }

    /// Requests camera access permission from the user.
    /// - Returns: True if permission is granted or already determined, false otherwise.
    func requestPermission() async -> Bool {
        print("CameraService: Requesting permission...")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var isAuthorized = status == .authorized

        if status == .notDetermined {
            print("CameraService: Permission not determined, requesting...")
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            print("CameraService: Permission request result: \(isAuthorized)")
        } else {
            print("CameraService: Permission status: \(status)")
        }

        if !isAuthorized {
            setupResult = .notAuthorized // Update setup result if not authorized
        }
        return isAuthorized
    }

    /// Configures and starts the session *after* checking permissions.
    /// Call this from CaptureView's onAppear.
    func configureAndStartSession() {
         print("CameraService: configureAndStartSession called.")
         guard setupResult == .success else { // Don't proceed if already failed (e.g., auth)
              print("CameraService: Skipping session start due to previous failure (\(setupResult)).")
              // You might want to publish an error state here
              return
         }

         // Ensure setup runs only once or is idempotent
         if captureSession == nil {
             setupSession() // Perform actual AVFoundation setup
         }

         guard setupResult == .success, let session = captureSession, !isSessionRunning else {
             print("CameraService: Session start aborted. SetupResult: \(setupResult), Session Exists: \(captureSession != nil), Is Running: \(isSessionRunning)")
             if setupResult != .success {
                  // Set an error state if setup failed
                  DispatchQueue.main.async {
                      self.photoCaptureError = CameraError.setupFailed("Configuration failed or permission denied.")
                  }
             }
             return
         }

         print("CameraService: Starting session on background thread...")
         DispatchQueue.global(qos: .userInitiated).async { [weak self] in
             session.startRunning()
             self?.isSessionRunning = true
             print("CameraService: Session started successfully.")
         }
     }

// Make setupSession private and ensure it sets setupResult on failure
    private func setupSession() {
        print("CameraService: setupSession - Configuring AVFoundation components.")
        // Check authorization status again just in case
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
             print("CameraService: setupSession - Error: Not authorized.")
             setupResult = .notAuthorized
             return
         }

        captureSession = AVCaptureSession() // Create session instance here
        guard let session = captureSession else {
             print("CameraService: setupSession - Failed to create AVCaptureSession.")
             setupResult = .configurationFailed
             return
        }
        session.sessionPreset = .photo // Use high quality preset

        // Find cameras
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
        } else {
            print("CameraService: setupSession - Front camera not found.")
        }
        // ... (find back camera if needed) ...
        currentCamera = frontCamera // Default to front

        guard let camera = currentCamera else {
            print("CameraService: setupSession - Error: No suitable camera found.")
            setupResult = .configurationFailed
            captureSession = nil
            return
        }
        print("CameraService: setupSession - Using camera: \(camera.localizedName)")

        // Add Input
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                 print("CameraService: setupSession - Camera input added.")
            } else {
                print("CameraService: setupSession - Error: Could not add camera input to session.")
                setupResult = .configurationFailed
                captureSession = nil
                return
            }
        } catch {
            print("CameraService: setupSession - Error creating camera input: \(error)")
            setupResult = .configurationFailed
            captureSession = nil
            return
        }

        // Add Output
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            self.photoOutput = output
            print("CameraService: setupSession - Photo output added.")
        } else {
            print("CameraService: setupSession - Error: Could not add photo output to session.")
            setupResult = .configurationFailed
            captureSession = nil
            return
        }

        // Configure Preview Layer - Ensure session is assigned
        let layer = AVCaptureVideoPreviewLayer(session: session) // Use the configured session
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait
        self.videoPreviewLayer = layer
        print("CameraService: setupSession - Preview layer configured.")

        setupResult = .success // Mark setup as successful if all steps passed
        print("CameraService: setupSession - Configuration successful.")
    }

    /// Stops the AVFoundation capture session on a background thread.
    func stopSession() {
        // Make sure session exists and is running before stopping
        guard let session = captureSession, isSessionRunning else {
             print("CameraService: stopSession - Session nil or not running.")
             return
        }
         print("CameraService: Stopping session on background thread...")
         DispatchQueue.global(qos: .userInitiated).async { [weak self] in
             // Check session again inside async block
             guard let self = self, let currentSession = self.captureSession, self.isSessionRunning else { return }
             currentSession.stopRunning()
             self.isSessionRunning = false
             print("CameraService: Session stopped.")
         }
    }

    /// Initiates photo capture using the configured photo output.
    func capturePhoto() {
         guard let output = photoOutput, isSessionRunning else {
             print("Error: Cannot capture photo. Session not running or output not configured.")
             DispatchQueue.main.async {
                 self.photoCaptureError = CameraError.captureFailed("Session not running or output nil")
             }
             return
         }
         print("CameraService: Initiating photo capture...")
         let photoSettings = AVCapturePhotoSettings()
         // Configure settings if needed (e.g., flash, format)
         output.capturePhoto(with: photoSettings, delegate: self)
     }

    // MARK: - Private Setup Methods

    /// Configures the AVCaptureSession, inputs, outputs, and preview layer.
    private func setupSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo // Use high quality preset

        // Find cameras
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
        }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = device
        }

        // Default to front camera
        currentCamera = frontCamera ?? backCamera

        guard let camera = currentCamera else {
            print("Error: No suitable camera found.")
            // Consider publishing an error state here
            return
        }

        // Add Input
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("Error: Could not add camera input to session.")
                return
            }
        } catch {
            print("Error creating camera input: \(error)")
            return
        }

        // Add Output
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            self.photoOutput = output
        } else {
            print("Error: Could not add photo output to session.")
            return
        }

        // Configure Preview Layer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait // Or dynamically update based on device orientation
        self.videoPreviewLayer = layer

        self.captureSession = session
        print("CameraService: Session configured successfully.")
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    /// Delegate callback when a photo has been processed.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async { // Ensure UI updates happen on the main thread
            if let error = error {
                print("Error capturing photo: \(error.localizedDescription)")
                self.photoCaptureError = CameraError.captureFailed(error.localizedDescription)
                self.capturedImage = nil
                return
            }

            guard let imageData = photo.fileDataRepresentation() else {
                print("Error: Could not get image data from captured photo.")
                self.photoCaptureError = CameraError.invalidData
                self.capturedImage = nil
                return
            }

            guard let image = UIImage(data: imageData) else {
                 print("Error: Could not create UIImage from data.")
                 self.photoCaptureError = CameraError.invalidData
                 self.capturedImage = nil
                 return
             }

            // Ensure the image is oriented correctly (especially from front camera)
            let correctlyOrientedImage = self.fixOrientation(img: image)

            print("CameraService: Photo captured successfully.")
            self.capturedImage = correctlyOrientedImage
            self.photoCaptureError = nil // Clear previous errors
        }
    }

    /// Corrects the orientation of an image, often needed for front camera captures.
    private func fixOrientation(img: UIImage) -> UIImage {
        if img.imageOrientation == .up {
            return img
        }

        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
        let rect = CGRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
        img.draw(in: rect)
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return normalizedImage
    }

    // MARK: - Custom Errors
    enum CameraError: Error, LocalizedError {
        case permissionDenied
        case setupFailed(String)
        case captureFailed(String)
        case invalidData

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Camera access permission was denied."
            case .setupFailed(let reason): return "Failed to set up camera: \(reason)"
            case .captureFailed(let reason): return "Failed to capture photo: \(reason)"
            case .invalidData: return "Captured photo data was invalid."
            }
        }
    }
}