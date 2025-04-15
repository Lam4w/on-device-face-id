import SwiftUI
import AVFoundation

/// A SwiftUI View that displays the camera preview feed.
struct CameraPreview: UIViewRepresentable {
    /// The CameraService instance providing the preview layer.
    @ObservedObject var cameraService: CameraService

    /// Creates the underlying UIView (the preview layer's view).
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds) // Or adjust frame as needed
        cameraService.previewLayer.frame = view.bounds // Set frame here too
        view.layer.addSublayer(cameraService.previewLayer)
        print("CameraPreview: UIView created and preview layer added.")
        return view
    }

    /// Updates the UIView if needed (e.g., layout changes).
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update frame if layout changes
        cameraService.previewLayer.frame = uiView.bounds
    }
}