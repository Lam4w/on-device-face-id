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

    override init() {
        super.init()
        setupSession()
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
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var isAuthorized = status == .authorized

        if status == .notDetermined {
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        }

        return isAuthorized
    }

    /// Starts the AVFoundation capture session on a background thread.
    func startSession() {
        guard let session = captureSession, !isSessionRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.startRunning()
            self?.isSessionRunning = true
            print("CameraService: Capture session started.")
        }
    }

    /// Stops the AVFoundation capture session on a background thread.
    func stopSession() {
        guard let session = captureSession, isSessionRunning else { return }
         DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.stopRunning()
            self?.isSessionRunning = false
            print("CameraService: Capture session stopped.")
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