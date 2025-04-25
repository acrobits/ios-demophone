import AVFoundation
import MediaPlayer
import SwiftUI
import AVKit

struct AirPlayView: UIViewRepresentable {
    
    private let routePickerView = AVRoutePickerView()

    func makeUIView(context: UIViewRepresentableContext<AirPlayView>) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<AirPlayView>) {
        routePickerView.tintColor = .white
        routePickerView.activeTintColor = .systemPink
        routePickerView.backgroundColor = .clear
        
        routePickerView.translatesAutoresizingMaskIntoConstraints = false
        uiView.addSubview(routePickerView)

        NSLayoutConstraint.activate([
            routePickerView.topAnchor.constraint(equalTo: uiView.topAnchor),
            routePickerView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
            routePickerView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor),
            routePickerView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor)
        ])
    }
    
    func showAirPlayMenu() {
        for view: UIView in routePickerView.subviews {
            if let button = view as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
    }
}

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
