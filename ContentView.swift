import SwiftUI

struct ContentView: View {
    /// The single source of truth for UI state and logic.
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView { // Use NavigationView for title and potential settings navigation
            VStack(spacing: 0) {
                // Camera Preview Area
                ZStack {
                    // Camera Preview using the UIViewRepresentable wrapper
                    CameraPreview(cameraService: viewModel.cameraService)
                        .ignoresSafeArea() // Allow preview to fill edges

                    // Overlay for Status Messages
                    VStack {
                        Spacer() // Push status to bottom
                        Text(viewModel.verificationStatus.description)
                            .font(.headline)
                            .padding(8)
                            .background(.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.bottom)
                             .animation(.easeInOut, value: viewModel.verificationStatus)
                             .transition(.opacity) // Fade status text
                    }
                     .opacity(viewModel.isProcessing || viewModel.verificationStatus != .idle ? 1.0 : 0.0) // Show only when processing or status is not idle

                }
                .frame(maxWidth: .infinity)
                 // Set a fixed aspect ratio or flexible height as needed
                 // .aspectRatio(3/4, contentMode: .fit) // Example aspect ratio
                 // Or use flexible height:
                 .layoutPriority(1) // Give preview higher priority for space


                // Enrolled Image Thumbnail (if enrolled)
                if let enrolledImg = viewModel.enrolledImage {
                    HStack {
                        Image(uiImage: enrolledImg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.green, lineWidth: 2))
                            .padding(.leading)

                        Text("Enrolled Face")
                            .font(.caption)

                        Spacer()

                        Button {
                            viewModel.deleteEnrollment()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .padding(.trailing)
                         .disabled(viewModel.isProcessing)
                    }
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6)) // Subtle background
                }


                // Error Message Display
                if let errorMsg = viewModel.errorMessage {
                    Text(errorMsg)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.2))
                         .transition(.opacity) // Fade error message
                         .onTapGesture { // Allow dismissing error by tapping
                             viewModel.errorMessage = nil
                         }
                }


                // Control Buttons Area
                HStack(spacing: 20) {
                    // Enroll Button
                    Button {
                        viewModel.enrollButtonTapped()
                    } label: {
                         Label(viewModel.isEnrolled ? "Re-Enroll" : "Enroll", systemImage: "person.badge.plus")
                             .frame(maxWidth: .infinity) // Make buttons fill width
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isEnrolled ? .orange : .blue) // Different color if already enrolled
                    .disabled(viewModel.isProcessing) // Disable during processing

                    // Verify Button
                    Button {
                        viewModel.verifyButtonTapped()
                    } label: {
                         Label("Verify", systemImage: "person.fill.checkmark")
                             .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!viewModel.isEnrolled || viewModel.isProcessing) // Disable if not enrolled or processing

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
            .sheet(isPresented: $viewModel.showSettings) {
                // Present the Settings View Modally
                 SettingsView(similarityThreshold: $viewModel.similarityThreshold)
            }
             .onAppear(perform: viewModel.onAppear) // Start camera etc. when view appears
             .onDisappear(perform: viewModel.onDisappear) // Stop camera when view disappears
             .animation(.default, value: viewModel.errorMessage) // Animate error appearance
             .animation(.default, value: viewModel.enrolledImage) // Animate thumbnail appearance
        } // End NavigationView
        .navigationViewStyle(.stack) // Use stack style for standard behavior
    }
}

// MARK: - Settings View (Simple Example)
struct SettingsView: View {
    @Binding var similarityThreshold: Double // Bind directly to ViewModel's @AppStorage
    @Environment(\.dismiss) var dismiss // To close the sheet

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Verification Threshold")
                    .font(.headline)

                Text("Adjust the similarity score required for a match. Higher values mean stricter matching.")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Text("Low (Loose)")
                    Slider(value: $similarityThreshold, in: 0.5...1.0, step: 0.01) // Example range for DeepLook similarity
                    Text("High (Strict)")
                }

                Text(String(format: "Current Threshold: %.2f", similarityThreshold))
                    .font(.subheadline)

                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss() // Close the sheet
                    }
                }
            }
        }
    }
}


// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            // You might want to inject mock services for previews if needed
            // .environmentObject(ContentViewModel(cameraService: MockCameraService(), ...))
    }
}