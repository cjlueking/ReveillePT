import AVFoundation
import SwiftUI

/// Shows the live camera. Uses aspect-fit so the skeleton overlay can be mapped with simple math.
struct CameraPreview: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let previewLayer { layer.addSublayer(previewLayer) }
                setNeedsLayout()
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

/// The rectangle an aspect-fit image of `aspect` (width/height) occupies inside `size`.
func fittedRect(aspect: Double, in size: CGSize) -> CGRect {
    guard aspect > 0, size.width > 0, size.height > 0 else { return .zero }
    let viewAspect = size.width / size.height
    if CGFloat(aspect) > viewAspect {
        let h = size.width / CGFloat(aspect)
        return CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h)
    } else {
        let w = size.height * CGFloat(aspect)
        return CGRect(x: (size.width - w) / 2, y: 0, width: w, height: size.height)
    }
}
