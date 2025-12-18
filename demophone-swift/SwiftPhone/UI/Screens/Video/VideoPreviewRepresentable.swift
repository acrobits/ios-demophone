import Foundation
import SwiftUI
import Softphone_Swift

#if VIDEO_FEATURE
struct VideoPreviewRepresentable: UIViewRepresentable {
    var previewArea: CGRect
    @Binding var reportedFrame: CGRect

    func makeUIView(context: Context) -> VideoPreview {
        let preview = VideoPreview()
        preview.backgroundColor = .black
        return preview
    }

    func updateUIView(_ uiView: VideoPreview, context: Context) {
        uiView.previewArea = previewArea
        uiView.updatePositionAndOrientation()
    }
}
#endif
