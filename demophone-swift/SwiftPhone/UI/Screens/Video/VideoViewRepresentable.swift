import Foundation
import SwiftUI
import Softphone_Swift

#if VIDEO_FEATURE
struct VideoViewRepresentable: UIViewRepresentable {
    let callEvent: SoftphoneCallEvent
    @Binding var videoAspectRatio: CGFloat?

    func makeCoordinator() -> Coordinator {
        Coordinator { ratio in
            DispatchQueue.main.async {
                self.videoAspectRatio = ratio
            }
        }
    }

    func makeUIView(context: Context) -> AspectFitVideoHostView {
        guard let vv = VideoView(call: callEvent) else {
            // Fallback empty view if VideoView can’t be created
            return AspectFitVideoHostView(videoView: VideoView())
        }

        vv.delegate = context.coordinator
        let host = AspectFitVideoHostView(videoView: vv)

        let initial = vv.videoRatio
        if initial.isFinite, initial > 0 {
            host.videoAspectRatio = initial
        }

        return host
    }

    func updateUIView(_ uiView: AspectFitVideoHostView, context: Context) {
        if let r = videoAspectRatio, r.isFinite, r > 0 {
            uiView.videoAspectRatio = r
        }
    }

    final class Coordinator: NSObject, VideoViewDelegate {
        private let onRatioChange: (CGFloat) -> Void
        private var lastRatio: CGFloat = 0

        init(onRatioChange: @escaping (CGFloat) -> Void) {
            self.onRatioChange = onRatioChange
        }

        func videoViewDidChangeFrameSize(_ view: VideoView) {
            let r = view.videoRatio
            guard r.isFinite, r > 0 else { return }

            // Debounce tiny jitters
            guard abs(r - lastRatio) > 0.01 else { return }
            lastRatio = r

            onRatioChange(r)
        }
    }
}

#endif
