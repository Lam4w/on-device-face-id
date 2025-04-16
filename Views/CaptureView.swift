import SwiftUI
import Combine

struct CaptureView: View {
    @ObservedObject var cameraService: CameraService
    let mode: CaptureMode
    var onComplete: (UIImage?) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var isCapturing: Bool = false
    @State private var captureErrorMessage: String? = nil
    @State private var showCameraFeed: Bool = false // State to delay preview until ready

    var body: some View {
        NavigationView {
            ZStack {
                // Make background visible for layout debugging
                Color.gray.opacity(0.3).ignoresSafeArea() // Temporary background

                // Only show CameraPreview if ready
                if showCameraFeed {
                    CameraPreview(cameraService: cameraService)
                        .ignoresSafeArea()
                        .transition(.opacity) // Optional fade-in
                } else {
                     // Show loading indicator or message while camera starts
                     VStack {
                         ProgressView()
                         Text("Starting Camera...")
                             .padding(.top)
                             .foregroundColor(.secondary)
                     }
                }


                // Overlay UI Elements (VStack)
                VStack {
                    // Instructions Text (unchanged)
                     Text(mode == .enroll ? "Position face for Enrollment" : "Position face for Verification")
                         // ... (styling) ...

                    Spacer() // Pushes controls to the bottom

                    // Capture Error Message (unchanged)
                    if let errorMsg = captureErrorMessage {
                         // ... (error text view) ...
                    }

                    // Capture Button (ensure it's visible)
                    Button {
                        if !isCapturing && showCameraFeed { // Only allow capture if feed is shown
                            print("Capture button tapped.")
                            isCapturing = true
                            captureErrorMessage = nil
                            cameraService.capturePhoto()
                        }
                    } label: {
                        // ... (Button ZStack styling - unchanged) ...
                    }
                    .padding(.bottom, 30)
                    .disabled(isCapturing || !showCameraFeed) // Disable if capturing OR feed not ready
                    .opacity(showCameraFeed ? 1.0 : 0.0) // Hide button until camera is ready

                } // End VStack
            } // End ZStack
            .onAppear {
                print("CaptureView: onAppear.")
                // Request permission and start session here
                Task {
                    let granted = await cameraService.requestPermission()
                    if granted {
                         print("CaptureView: Permission granted. Configuring session...")
                         // Now configure and start
                         cameraService.configureAndStartSession()
                         // Allow a brief moment for session to start before showing preview
                         // Adjust delay if needed, or monitor session running state
                         try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                         await MainActor.run { // Ensure UI update is on main thread
                             self.showCameraFeed = true
                             print("CaptureView: Showing camera feed.")
                         }
                    } else {
                         print("CaptureView: Permission denied.")
                         captureErrorMessage = "Camera permission is required."
                         // Optionally dismiss or show error prominently
                         await Task.sleep(seconds: 2) // Show error briefly
                         dismiss() // Auto-dismiss if no permission
                         onComplete(nil) // Signal cancellation due to no permission
                    }
                }
            }
            .onDisappear {
                 print("CaptureView: onDisappear. Stopping session.")
                 cameraService.stopSession()
                 showCameraFeed = false // Reset state when view disappears
            }
            // onReceive handlers remain the same
             .onReceive(cameraService.$capturedImage) { image in
                  // ... (existing code) ...
             }
             .onReceive(cameraService.$photoCaptureError) { error in
                  // ... (existing code to set captureErrorMessage and isCapturing=false) ...
                  if let captureError = error {
                      print("CaptureView received error: \(captureError.localizedDescription)")
                      captureErrorMessage = "Capture failed: \(captureError.localizedDescription)"
                      isCapturing = false
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
                             cameraService.stopSession()
                             isCapturing = false
                        }
                        onComplete(nil) // Signal cancellation
                        dismiss()
                    }
                }
            }
        } // End NavigationView
        // Add an alert for critical errors like permission denied?
        .alert("Camera Error", isPresented: .constant(captureErrorMessage != nil && !showCameraFeed)) { // Show alert if critical error before feed appears
             Button("OK", role: .cancel) {
                 dismiss()
                 onComplete(nil)
             }
        } message: {
             Text(captureErrorMessage ?? "An unknown camera error occurred.")
        }
    }
}

// Helper extension for Task.sleep with seconds
extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async {
        let duration = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: duration)
    }
}