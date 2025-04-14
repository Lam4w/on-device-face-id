import SwiftUI
import AVFoundation

/// Main content view for the app
struct ContentView: View {
    @StateObject private var viewModel = FaceRecognitionViewModel()
    @State private var showingSettings = false
    @State private var showingEnrollSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Camera preview
                CameraPreviewView(viewModel: viewModel)
                    .aspectRatio(3/4, contentMode: .fit)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary, lineWidth: 1)
                    )
                    .padding()
                
                // Status message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                // Verification result
                if case .results(let result) = viewModel.appState {
                    VerificationResultView(result: result)
                        .padding()
                }
                
                // Controls
                HStack(spacing: 20) {
                    Button(action: {
                        showingEnrollSheet = true
                    }) {
                        Label("Enroll", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.appState != .idle)
                    
                    Button(action: {
                        viewModel.captureForVerification()
                    }) {
                        Label("Verify", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.appState != .idle || viewModel.storedFaces.isEmpty)
                }
                .padding()
                
                // Show enrolled faces count
                Text("Enrolled faces: \(viewModel.storedFaces.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle("Face Recognition")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingEnrollSheet) {
                EnrollView(viewModel: viewModel, isPresented: $showingEnrollSheet)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.startCamera()
            }
            .onDisappear {
                viewModel.stopCamera()
            }
        }
    }
}

/// Camera preview view
struct CameraPreviewView: View {
    @ObservedObject var viewModel: FaceRecognitionViewModel
    
    var body: some View {
        ZStack {
            if let previewImage = viewModel.previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
                Text("Initializing camera...")
                    .foregroundColor(.white)
            }
            
            // Overlay for processing state
            if viewModel.appState == .processing || viewModel.appState == .capturing {
                Color.black.opacity(0.5)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
            }
        }
    }
}

/// View for enrolling a new face
struct EnrollView: View {
    @ObservedObject var viewModel: FaceRecognitionViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter name", text: $viewModel.enrollName)
                .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Make sure you're in good lighting and position your face clearly in the frame.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    viewModel.captureForEnrollment()
                    isPresented = false
                }) {
                    Label("Capture Face", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .disabled(viewModel.enrollName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Enroll New Face")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}

/// View for verification results
struct VerificationResultView: View {
    let result: VerificationResult
    
    var body: some View {
        VStack(spacing: 12) {
            switch result {
            case .match(let face, let distance):
                Image(systemName: "person.fill.checkmark")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                
                Text("Match found!")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text("Hello, \(face.name)")
                    .font(.title2)
                
                Text("Confidence: \(confidencePercentage(from: distance))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
            case .noMatch:
                Image(systemName: "person.fill.xmark")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                
                Text("No match found")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Text("This face is not recognized")
                    .font(.subheadline)
                
            case .error(let error):
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    /// Converts distance to confidence percentage
    /// - Parameter distance: Raw distance value (lower is better)
    /// - Returns: Confidence percentage (higher is better)
    private func confidencePercentage(from distance: Float) -> Int {
        // Convert distance to confidence (0-100%)
        // Distance is typically 0-1 where lower is better
        let confidence = max(0, min(100, Int((1 - distance) * 100)))
        return confidence
    }
}

/// Settings view
struct SettingsView: View {
    @ObservedObject var viewModel: FaceRecognitionViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Matching Threshold"),
                        footer: Text("Lower values require closer matches. Adjust if you're getting false positives or negatives.")) {
                    VStack {
                        HStack {
                            Text("Strict")
                            Slider(value: $viewModel.similarityThreshold, in: 0.1...1.0, step: 0.05)
                            Text("Lenient")
                        }
                        
                        Text("Current: \(viewModel.similarityThreshold, specifier: "%.2f")")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                Section(header: Text("Enrolled Faces")) {
                    if viewModel.storedFaces.isEmpty {
                        Text("No faces enrolled")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(viewModel.storedFaces) { face in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text(face.name)
                                    Text(face.dateAdded, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.removeFace(id: face.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete All Enrolled Faces", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(viewModel.storedFaces.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .confirmationDialog(
                "Are you sure you want to delete all enrolled faces?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    viewModel.storageService.clearAllFaces()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}