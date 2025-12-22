import Foundation
import SwiftUI
import Softphone_Swift

#if VIDEO_FEATURE
struct AdaptiveVideoView: View {
    let callEvent: SoftphoneCallEvent
    
    // Default to a vertical aspect ratio (3:4) until the delegate fires.
    @State private var videoRatio: CGFloat = 0.75
    
    var body: some View {
        VideoViewRepresentable(callEvent: callEvent) { newRatio in
            self.videoRatio = newRatio
        }
        // This ensures the view takes exactly the space required by the video
        .aspectRatio(videoRatio, contentMode: .fit)
    }
}

struct VideoViewRepresentable: UIViewRepresentable {
    let callEvent: SoftphoneCallEvent
    
    /// Closure to report back when the video frame/ratio changes
    var onRatioChange: ((CGFloat) -> Void)?
    
    func makeCoordinator() -> VideoViewCoordinator {
        VideoViewCoordinator(self)
    }
    
    func makeUIView(context: Context) -> VideoView {
        // Assuming VideoView(call:) exists based on your code
        let view = VideoView(call: callEvent)
        view?.delegate = context.coordinator
        view?.contentMode = .scaleAspectFit
        view?.backgroundColor = .black
        return view ?? VideoView()
    }
    
    func updateUIView(_ uiView: VideoView, context: Context) {
        // Update parent reference so closure capture is fresh
        context.coordinator.parent = self
    }
}

final class VideoViewCoordinator: NSObject, VideoViewDelegate {
    var parent: VideoViewRepresentable
    
    init(_ parent: VideoViewRepresentable) {
        self.parent = parent
    }
    
    func videoViewDidChangeFrameSize(_ view: VideoView) {
        guard view.videoFrameSize.height > 0 else { return }
        
        // Calculate new aspect ratio
        let ratio = view.videoFrameSize.width / view.videoFrameSize.height
        
        print("[Video] Frame changed: \(view.videoFrameSize), New Ratio: \(ratio)")
        
        // Push to main thread to update SwiftUI State
        DispatchQueue.main.async { [weak self] in
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.parent.onRatioChange?(ratio)
            }
        }
    }
}
#endif
