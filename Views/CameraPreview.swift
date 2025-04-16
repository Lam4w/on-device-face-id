import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService

    func makeUIView(context: Context) -> UIView {
        let view = UIView() // Use default frame initially
        // Ensure previewLayer is available before adding
        if let layer = cameraService.videoPreviewLayer {
             // Critical: Set the frame BEFORE adding the sublayer if possible
             // layer.frame = view.bounds // Bounds might be zero here initially
             view.layer.addSublayer(layer)
             print("CameraPreview: makeUIView - Preview layer added to view.")
        } else {
             print("CameraPreview: makeUIView - Warning: Preview layer was nil.")
        }
        view.backgroundColor = .black // Set background to see view bounds easily
        print("CameraPreview: makeUIView - View created.")
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // This is where the frame is likely set correctly after layout
        if let layer = cameraService.videoPreviewLayer {
            // Ensure the layer's frame matches the UIView's bounds after layout
            if layer.frame != uiView.bounds {
                 layer.frame = uiView.bounds
                 print("CameraPreview: updateUIView - Updated preview layer frame to: \(uiView.bounds)")
            }
             // Add layer here if it wasn't added in makeUIView (e.g., if session wasn't ready)
             if layer.superlayer == nil {
                 uiView.layer.addSublayer(layer)
                 print("CameraPreview: updateUIView - Added preview layer as it wasn't present.")
             }
        } else {
             print("CameraPreview: updateUIView - Warning: Preview layer is nil during update.")
        }
         print("CameraPreview: updateUIView - View frame: \(uiView.frame)")
    }
}