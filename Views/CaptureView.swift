import SwiftUI
import Combine

struct CaptureView: View {
    /// The camera service instance, passed from the parent.
    @ObservedObject var cameraService: CameraService
    /// The mode (enroll/verify) determines UI text/behavior slightly.
    let mode: CaptureMode
    /// Callback closure to execute when capture is complete or cancelled.
    var onComplete: (UIImage?) -> Void

    /// Environment value to dismiss the sheet.
    @Environment(\.dismiss) var dismiss
    /// State to track if a capture is in progress.
    @State private var isCapturing: Bool = false
    /// State to hold any capture-specific errors.
    @State private var captureErrorMessage: String? = nil

    var body: some View {
        NavigationView { // Embed in NavigationView for title and toolbar
            ZStack {
                // Camera Preview takes up the background
                CameraPreview(cameraService: cameraService)
                    .ignoresSafeArea()
                    .onAppear {
                        print("CaptureView Appeared: Starting camera session.")
                        cameraService.startSession()
                    }
                    .onDisappear {
                         print("CaptureView Disappeared: Stopping camera session.")
                         // Stop session even if capture is in progress, delegate handles result
                         cameraService.stopSession()
                         // Reset capturing state if view disappears unexpectedly
                         isCapturing = false
                    }

                // Overlay UI Elements
                VStack {
                    // Instructions Text
                     Text(mode == .enroll ? "Position face for Enrollment" : "Position face for Verification")
                         .padding(12)
                         .background(.black.opacity(0.6))
                         .foregroundColor(.white)
                         .cornerRadius(10)
                         .padding(.top)


                    Spacer() // Pushes controls to the bottom

                    // Capture Error Message
                    if let errorMsg = captureErrorMessage {
                        Text(errorMsg)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.bottom, 5)
                            .transition(.opacity)
                            .onTapGesture {
                                captureErrorMessage = nil // Allow dismissing
                            }
                    }

                    // Capture Button
                    Button {
                        if !isCapturing {
                            print("Capture button tapped.")
                            isCapturing = true
                            captureErrorMessage = nil // Clear previous errors
                            cameraService.capturePhoto()
                        }
                    } label: {
                        ZStack {
                             Circle()
                                .fill(isCapturing ? Color.gray : Color.white)
                                .frame(width: 70, height: 70)
                             Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            if isCapturing {
                                ProgressView() // Show spinner while capturing
                                    .tint(.white)
                                    .scaleEffect(1.5)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                    .disabled(isCapturing) // Disable while capture is processing
                }
            }
             // React to captured image changes from the service
            .onReceive(cameraService.$capturedImage) { image in
                 if let capturedImage = image, isCapturing {
                     print("CaptureView received image.")
                     // Prevent receiving again if dismissal is slow
                     cameraService.capturedImage = nil
                     isCapturing = false
                     onComplete(capturedImage) // Send image back via closure
                     // Dismissal might be handled by the parent setting showCaptureSheet=false
                     // Or we can explicitly dismiss here:
                     // dismiss()
                 }
             }
             // React to photo capture errors from the service
            .onReceive(cameraService.$photoCaptureError) { error in
                if let captureError = error {
                    print("CaptureView received error: \(captureError.localizedDescription)")
                    captureErrorMessage = "Capture failed: \(captureError.localizedDescription)"
                    isCapturing = false // Re-enable button on error
                    // Clear the error in the service so it doesn't trigger again
                    cameraService.photoCaptureError = nil
                }
            }
            .navigationTitle(mode == .enroll ? "Enroll Face" : "Verify Face")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        print("Cancel button tapped.")
                        if isCapturing {
                             // If capture is ongoing, wait for it finish/fail?
                             // Or just stop session and dismiss? Let's dismiss.
                             cameraService.stopSession()
                             isCapturing = false
                        }
                        onComplete(nil) // Signal cancellation
                        dismiss()
                    }
                }
            }
        } // End NavigationView
    }
}