import UIKit
import Softphone_Swift

final class AspectFitVideoHostView: UIView {
    
    let videoView: VideoView
    var videoAspectRatio: CGFloat = 16.0 / 9.0 {   // width / height
        didSet { setNeedsLayout() }
    }
    
    init(videoView: VideoView) {
        self.videoView = videoView
        super.init(frame: .zero)
        
        backgroundColor = .black
        clipsToBounds = true
        
        addSubview(videoView)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let ratio = videoView.videoRatio
        videoView.frame = frameForBounds(bounds, withRatio: ratio)
        videoView.clipsToBounds = true
    }
    
    private func frameForBounds(_ bounds: CGRect, withRatio videoRatio: CGFloat) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return bounds }
        guard videoRatio.isFinite, videoRatio > 0 else { return bounds }
        
        let w = bounds.width
        let h = bounds.height
        let viewRatio = w / h
        
        var fittedW: CGFloat
        var fittedH: CGFloat
        
        if videoRatio > viewRatio {
            fittedW = w
            fittedH = w / videoRatio
        } else {
            fittedH = h
            fittedW = h * videoRatio
        }
        
        let x = (w - fittedW) / 2.0
        let y = (h - fittedH) / 2.0
        
        return CGRect(
            x: floor(bounds.minX + x),
            y: floor(bounds.minY + y),
            width: floor(fittedW),
            height: floor(fittedH)
        )
    }
}
