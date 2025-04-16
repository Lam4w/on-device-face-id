// CaptureView.swift (Updated)

import SwiftUI
import Combine

struct CaptureView: View {
    @ObservedObject var cameraService: CameraService
    let mode: CaptureMode
    var onComplete: (UIImage?) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var isCapturing: Bool = false
    @State private var captureErrorMessage: String? = nil
    @State private var showCameraFeed: Bool = false // Keep this for smooth loading

    // Calculate circle diameter (e.g., 80% of screen width)
    private var circleDiameter: CGFloat {
        UIScreen.main.bounds.width * 0.8
    }

    var body: some View {
        NavigationView {
            // Main container VStack
            VStack(spacing: 20) { // Add some spacing between elements
                Spacer() // Push content down from Cancel button

                // Circular Camera Preview Area
                ZStack {
                    // Only show CameraPreview if ready
                    if showCameraFeed {
                        CameraPreview(cameraService: cameraService)
                            // Set a specific square frame for the preview
                            .frame(width: circleDiameter, height: circleDiameter)
                            // Clip the preview view into a circle
                            .clipShape(Circle())
                            // Optional: Add a simple white border like Face ID setup
                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 4))
                            .transition(.opacity) // Fade in
                    } else {
                        // Placeholder while loading
                        Circle()
                            .fill(Color.gray.opacity(0.3)) // Placeholder circle
                            .frame(width: circleDiameter, height: circleDiameter)
                            .overlay(ProgressView()) // Show spinner inside placeholder
                    }
                }
                // Explicitly frame the ZStack to ensure layout space
                .frame(width: circleDiameter, height: circleDiameter)


                // Instructions Text (Style like image)
                Text(mode == .enroll ? "Position face within the circle" : "Position face for Verification")
                    .foregroundColor(.white) // White text on black background
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal) // Add horizontal padding

                Spacer() // Push button towards bottom

                // Capture Error Message (Keep for error feedback)
                if let errorMsg = captureErrorMessage {
                    Text(errorMsg)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 5)
                        .transition(.opacity)
                        .onTapGesture {
                            captureErrorMessage = nil
                        }
                }

                // Capture Button (Keep existing style below the circle)
                Button {
                    if !isCapturing && showCameraFeed {
                        print("Capture button tapped.")
                        isCapturing = true
                        captureErrorMessage = nil
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
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        }
                    }
                }
                .padding(.bottom, 30)
                .disabled(isCapturing || !showCameraFeed)
                .opacity(showCameraFeed ? 1.0 : 0.0) // Hide button until camera is ready

            } // End main VStack
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure VStack fills space
            .background(Color.black.ignoresSafeArea()) // Set black background, extending into safe areas
            .onAppear {
                print("CaptureView: onAppear.")
                // Keep the permission check and session start logic here
                Task {
                    let granted = await cameraService.requestPermission()
                    if granted {
                         print("CaptureView: Permission granted. Configuring session...")
                         cameraService.configureAndStartSession()
                         try? await Task.sleep(nanoseconds: 150_000_000)
                         await MainActor.run {
                             self.showCameraFeed = true
                             print("CaptureView: Showing camera feed.")
                         }
                    } else {
                         // ... (permission denied handling remains the same) ...
                         print("CaptureView: Permission denied.")
                         captureErrorMessage = "Camera permission is required."
                         await Task.sleep(seconds: 2)
                         dismiss()
                         await onComplete(nil) // Ensure completion handler is called even on error dismissal
                    }
                }
            }
            .onDisappear {
                 print("CaptureView: onDisappear. Stopping session.")
                 cameraService.stopSession()
                 showCameraFeed = false
            }
            // onReceive handlers remain the same
             .onReceive(cameraService.$capturedImage) { image in
                 if let capturedImage = image, isCapturing {
                     print("CaptureView received image.")
                     cameraService.capturedImage = nil
                     isCapturing = false
                     Task {
                         await onComplete(capturedImage)
                     }
                 }
             }
             .onReceive(cameraService.$photoCaptureError) { error in
                 if let captureError = error {
                     print("CaptureView received error: \(captureError.localizedDescription)")
                     captureErrorMessage = "Capture failed: \(captureError.localizedDescription)"
                     isCapturing = false
                     cameraService.photoCaptureError = nil
                 }
             }
            // Navigation Title can be removed if not desired for this look
            // .navigationTitle(mode == .enroll ? "Enroll Face" : "Verify Face")
            .navigationBarTitleDisplayMode(.inline) // Keep inline if title is present
            .toolbar {
                // Keep Cancel button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        print("Cancel button tapped.")
                        if isCapturing {
                             cameraService.stopSession()
                             isCapturing = false
                        }
                        // Call completion handler with nil on manual cancel
                        Task { await onComplete(nil) }
                        dismiss()
                    }
                    .foregroundColor(.white) // Make Cancel button white for contrast
                }
            }
        } // End NavigationView
        .accentColor(.white) // Ensure toolbar items default to white if needed
        // Alert can remain the same
        .alert("Camera Error", isPresented: .constant(captureErrorMessage != nil && !showCameraFeed)) {
             Button("OK", role: .cancel) {
                 dismiss()
                 Task { await onComplete(nil) } // Call completion handler on error dismissal
             }
        } message: {
             Text(captureErrorMessage ?? "An unknown camera error occurred.")
        }
    }
}
