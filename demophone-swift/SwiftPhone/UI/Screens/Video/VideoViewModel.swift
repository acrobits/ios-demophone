import Foundation
import Combine
import Softphone_Swift

#if VIDEO_FEATURE
class VideoViewModel: ObservableObject {
    private var cancellable = Set<AnyCancellable>()
    private var videoService: VideoService
    
    @Published var cameras: [VideoCameraInfo] = []
    @Published var callsWithVideos: [SoftphoneCallEvent] = []
    
    var isVideoEnabled = false {
        didSet {
            updateVideoState(isVideoEnabled)
        }
    }
    
    @Published var isIncomingVideoEnabled = false
    @Published var isOutgoingVideoEnabled = false
    
    init() {
        self.videoService = AppDelegate.theApp().videoService
        
        self.videoService.onCallsWithVideoUpdated.sink { [weak self] calls in
            self?.callsWithVideos = calls
            self?.updateVideoState()
        }
        .store(in: &cancellable)
        
        loadCameras()
    }
    
    private func updateVideoState() {
        if callsWithVideos.isEmpty {
            isIncomingVideoEnabled = false
            isOutgoingVideoEnabled = false
            return
        }
        
        var incomingEnabled = false
        var outgoingEnabled = false
        
        for call in callsWithVideos {
            let streamAvailability = SoftphoneBridge.instance().calls().isVideoAvailable(call)
            if let streamAvailability = streamAvailability {
                incomingEnabled = incomingEnabled || streamAvailability.incoming
                outgoingEnabled = outgoingEnabled || streamAvailability.outgoing
            }
        }
        
        isIncomingVideoEnabled = incomingEnabled
        isOutgoingVideoEnabled = outgoingEnabled
        isVideoEnabled = isIncomingVideoEnabled || isOutgoingVideoEnabled
    }
    
    private func updateVideoState(_ enabled: Bool) {
        if enabled {
            self.videoService.updateDesiredMedia(desiredMedia: CallDesiredMedia.videoBothWays())
        } else {
            self.videoService.updateDesiredMedia(desiredMedia: CallDesiredMedia.voiceOnly())
        }
    }
    
    private func loadCameras() {
        var videoCameras = [VideoCameraInfo]()
        if let allCameras = SoftphoneBridge.instance().video().enumerateCameras() {
            for camera in allCameras {
                if camera.id == "__black_camera__" || camera.id == "__null_camera__" {
                    continue
                }
                videoCameras.append(camera)
            }
        }
        
        cameras = videoCameras
    }
    
    func toggleVideo() {
        isVideoEnabled.toggle()
    }
    
    func switchCamera() {
        if let currentCameraInfo = SoftphoneBridge.instance().video().getCurrentCamera() {
            let cameraInfo = cameras.first { $0.id != currentCameraInfo.id }
            SoftphoneBridge.instance().video().switchCamera(info: cameraInfo)
        }
    }
    
    func endCall() {
        if let activeGroup = SoftphoneBridge.instance().calls().conferences().getActive() {
            if activeGroup.isEmpty {
                return
            }
            
            AppDelegate.theApp().hangupGroup(groupId: activeGroup)
        }
    }
}
#endif
