import AVFoundation
import MediaPlayer

class VolumeView: MPVolumeView {
    private var volumeSlider: UIView?
    
    override func addSubview(_ subview: UIView) {
        let subViewClassName = String(describing: type(of: subview.self))
        if subViewClassName != "MPVolumeSlider" {
            super.addSubview(subview)
        }
        else {
            volumeSlider = subview
        }
    }
}

class AudioRoutePickerProxy {
    private var bluetoothButton: UIControl?
    private var volumeView: MPVolumeView?

    init() {
        volumeView = VolumeView(frame: .zero)
        
        for case let button as UIButton in volumeView?.subviews ?? [] {
            bluetoothButton = button
        }
    }
    
    func show(in view: UIView) {
        hide()
        
        if let v = volumeView {
            view.addSubview(v)
            bluetoothButton?.sendActions(for: .touchUpInside)
        }
    }
    
    func hide() {
        volumeView?.isHidden = true
        volumeView?.removeFromSuperview()
    }
    
    var wirelessRoutesAvailable: Bool {
        var wirelessRoutes = 0
        if let availableInputs = AVAudioSession.sharedInstance().availableInputs {
            availableInputs.forEach {
                if $0.portType == AVAudioSession.Port.bluetoothHFP || $0.portType == AVAudioSession.Port.carAudio {
                    wirelessRoutes += 1
                }
            }
        }
        return wirelessRoutes > 0
    }
}
