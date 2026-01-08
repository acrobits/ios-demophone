import Softphone_Swift
import Combine

#if VIDEO_FEATURE
class VideoService : NSObject {
    var onCallsWithVideoUpdated: CurrentValueSubject<[SoftphoneCallEvent], Never> = .init([])
    
    func refresh() {
        var callsWithVideo: [SoftphoneCallEvent] = []
        
        if let activeGroup = SoftphoneBridge.instance().calls().conferences().getActive() {
            if activeGroup.isEmpty {
                return
            }
            
            if let calls = SoftphoneBridge.instance().calls().conferences().getCalls(conference: activeGroup) {
                for call in calls {
                    if let streamAvailability = SoftphoneBridge.instance().calls().isVideoAvailable(call) {
                        if streamAvailability.incoming || streamAvailability.outgoing {
                            callsWithVideo.append(call)
                        }
                    }
                }
            }
        }
        
        onCallsWithVideoUpdated.send(callsWithVideo)
    }
    
    func updateDesiredMedia(desiredMedia: CallDesiredMedia) {
        if let activeGroup = SoftphoneBridge.instance().calls().conferences().getActive() {
            if activeGroup.isEmpty {
                return
            }
         
            if let calls = SoftphoneBridge.instance().calls().conferences().getCalls(conference: activeGroup) {
                for call in calls {
                    let success = SoftphoneBridge.instance().calls().setDesiredMedia(call, desiredMedia: desiredMedia)
                    print("desired media success = \(success)")
                }
            }
        }
    }
}
#endif
