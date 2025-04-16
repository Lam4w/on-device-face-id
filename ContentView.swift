import SwiftUI

struct ContentView: View {
    /// The single source of truth for UI state and logic.
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView { // Use NavigationView for title and potential settings navigation
            VStack(spacing: 0) { // Main content area

                Spacer() // Push content towards center/bottom

                // Enrolled Image Thumbnail (if enrolled)
                if let enrolledImg = viewModel.enrolledImage {
                    VStack {
                         Text("Enrolled Face:")
                             .font(.headline)
                             .padding(.bottom, 5)
                         Image(uiImage: enrolledImg)
                             .resizable()
                             .scaledToFit()
                             .frame(width: 150, height: 150) // Make it larger
                             .clipShape(Circle())
                             .overlay(Circle().stroke(Color.green, lineWidth: 3))

                         Button {
                            viewModel.deleteEnrollment()
                         } label: {
                             Label("Delete Enrollment", systemImage: "trash")
                                 .font(.caption)
                         }
                         .tint(.red)
                         .padding(.top, 5)
                         .disabled(viewModel.isProcessing) // Disable during any processing
                    }
                    .padding(.vertical)
                    .transition(.opacity.combined(with: .scale))
                } else {
                     Text("No face enrolled yet.")
                         .foregroundColor(.secondary)
                         .padding()
                }

                Spacer()

                // Status Message Area
                Text(viewModel.verificationStatus.description)
                    .font(.headline)
                    .padding()
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 50) // Ensure space for text
                     .animation(.easeInOut, value: viewModel.verificationStatus)
                     .transition(.opacity)

                 // Processing Indicator (shown during DeepLook/Storage work)
                 if viewModel.isProcessing {
                      ProgressView()
                         .padding(.bottom)
                 } else {
                      // Placeholder to prevent layout jumps when ProgressView disappears
                      Spacer().frame(height: 20).padding(.bottom) // Adjust height to match ProgressView approx size
                 }


                // Error Message Display
                if let errorMsg = viewModel.errorMessage {
                    Text(errorMsg)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(8)
                        .transition(.opacity)
                        .onTapGesture {
                             viewModel.errorMessage = nil
                         }
                        .padding(.horizontal) // Padding around the error background
                        .padding(.bottom, 5)
                } else {
                     // Placeholder to prevent layout jumps
                     Spacer().frame(height: 40).padding(.horizontal).padding(.bottom, 5) // Adjust height
                }


                // Control Buttons Area
                HStack(spacing: 20) {
                    // Enroll Button
                    Button {
                        viewModel.enrollButtonTapped() // Triggers sheet presentation
                    } label: {
                         Label(viewModel.isEnrolled ? "Re-Enroll" : "Enroll", systemImage: "person.badge.plus")
                             .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isEnrolled ? .orange : .blue)
                    // Disable only if DeepLook/Storage is processing, allow triggering sheet
                    .disabled(viewModel.isProcessing)

                    // Verify Button
                    Button {
                        viewModel.verifyButtonTapped() // Triggers sheet presentation
                    } label: {
                         Label("Verify", systemImage: "person.fill.checkmark")
                             .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    // Disable if not enrolled OR if DeepLook/Storage is processing
                    .disabled(!viewModel.isEnrolled || viewModel.isProcessing)

                }
                .padding()
                .background(.thinMaterial) // Background for button area

            } // End Main VStack
            .navigationTitle("Face Recognition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                     .disabled(viewModel.isProcessing)
                }
            }
             // Sheet for presenting the CaptureView
            .sheet(isPresented: $viewModel.showCaptureSheet) {
                 // This gets called when the sheet is dismissed programmatically OR by user gesture
                 print("Capture sheet dismissed.")
                 // Optional: Reset status if needed when dismissed manually without capture
                 // if viewModel.verificationStatus != .enrollmentSuccess && ... etc
             } content: {
                 // Content of the sheet
                 CaptureView(
                    cameraService: viewModel.cameraService, // Pass the camera service instance
                    mode: viewModel.currentCaptureMode // Pass the current mode
                 ) { capturedImage in
                     // This closure is called by CaptureView on completion/cancel
                     viewModel.handleCaptureCompletion(image: capturedImage, mode: viewModel.currentCaptureMode)
                 }
             }
            // Sheet for settings (unchanged)
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView(similarityThreshold: $viewModel.similarityThreshold)
            }
             .onAppear(perform: viewModel.onAppear) // Load initial state, request permission
             // .onDisappear(perform: viewModel.onDisappear) // No longer needed for camera
             .animation(.default, value: viewModel.errorMessage) // Animate error appearance
             .animation(.default, value: viewModel.enrolledImage) // Animate thumbnail appearance
             .animation(.default, value: viewModel.isProcessing) // Animate progress view
        } // End NavigationView
        .navigationViewStyle(.stack)
    }
}

// MARK: - Settings View (Unchanged)
// SettingsView remains the same as before

// MARK: - Preview (May need adjustment if mocks are used)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            // If using mock services, ensure they are updated or provide basic functionality
            // .environmentObject(ContentViewModel(cameraService: MockCameraService(), ...))
    }
}