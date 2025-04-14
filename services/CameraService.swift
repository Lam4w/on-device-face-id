import Foundation
import AVFoundation
import UIKit

/// Service responsible for camera operations
class CameraService: NSObject, ObservableObject {
    /// The capture session
    private let captureSession = AVCaptureSession()
    
    /// Video preview layer
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// Photo output
    private let photoOutput = AVCapturePhotoOutput()
    
    /// Video output for preview
    private let videoOutput = AVCaptureVideoDataOutput()
    
    /// Camera position (front by default)
    private var cameraPosition: AVCaptureDevice.Position = .front
    
    /// Queue for processing video frames
    private let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
    
    /// Callback for preview images
    var captureCallback: ((UIImage) -> Void)?
    
    /// Checks if the camera is running
    var isRunning: Bool {
        captureSession.isRunning
    }
    
    /// Initializes the camera
    override init() {
        super.init()
    }
    
    /// Starts the camera session
    /// - Throws: FaceRecognitionError if camera setup fails
    func start() async throws {
        // Check authorization status
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw FaceRecognitionError.cameraUnavailable
            }
        } else if status != .authorized {
            throw FaceRecognitionError.cameraUnavailable
        }
        
        // Reset capture session
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        
        // Set up camera input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            throw FaceRecognitionError.cameraUnavailable
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                throw FaceRecognitionError.cameraUnavailable
            }
            
            // Set up photo output
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
                photoOutput.maxPhotoQualityPrioritization = .quality
            } else {
                throw FaceRecognitionError.cameraUnavailable
            }
            
            // Set up video output for preview
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
                if let connection = videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                    // Mirror video for front camera
                    if cameraPosition == .front {
                        connection.isVideoMirrored = true
                    }
                }
            }
            
            captureSession.commitConfiguration()
            
            // Start running on a background thread
            Task.detached(priority: .userInitiated) {
                self.captureSession.startRunning()
            }
        } catch {
            throw FaceRecognitionError.cameraUnavailable
        }
    }
    
    /// Stops the camera session
    func stop() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    /// Captures a still image
    /// - Parameter completion: Callback with Result containing UIImage or Error
    func captureStillImage(completion: @escaping (Result<UIImage, Error>) -> Void) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureProcessor { image, error in
            if let error = error {
                completion(.failure(error))
            } else if let image = image {
                completion(.success(image))
            } else {
                completion(.failure(FaceRecognitionError.processingError("Unknown capture error")))
            }
        })
    }
    
    /// Toggles between front and back camera
    func toggleCamera() async throws {
        cameraPosition = cameraPosition == .front ? .back : .front
        try await start()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let captureCallback = captureCallback,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async {
            captureCallback(image)
        }
    }
}

/// Helper class to process photo capture
private class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?, Error?) -> Void
    
    init(completion: @escaping (UIImage?, Error?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(nil, error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(nil, FaceRecognitionError.processingError("Failed to create image from data"))
            return
        }
        
        completion(image, nil)
    }
}