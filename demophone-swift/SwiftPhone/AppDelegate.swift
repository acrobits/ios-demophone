import UIKit
import PushKit
import CallKit
import Softphone_Swift

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
enum ImagePurpose
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    case payload
    case networkPreview
    case localPreview
    case temporaryLocalPreview
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
public enum SdkState
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    case stopped
    case running
    case terminating
}

typealias TerminatingCallback = () -> Void

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
@UIApplicationMain
class AppDelegate: UIResponder
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    let serializer = NSLogSerializer(prefix: "")
    
    var window: UIWindow?
    var sipAccount: XmlTree!
    var regViewController: RegViewController!
    var callViewController: CallViewController!
    
    var pushKitRegistry: PKPushRegistry!
    var pushHandles = [String: AnyObject]()
    
    var securityAlerts = [String: UIAlertController]()
    
    var softphoneObserverProxy: SoftphoneObserverProxyBridge!
    
    var sdkState: SdkState = .stopped
    var terminatingTimer: Timer?
    var terminatingCallbacks: [TerminatingCallback] = []
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    class func theApp() -> AppDelegate
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let delegate = UIApplication.shared.delegate as! AppDelegate
        return delegate
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func registerForPushNotifications()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let preferences = SoftphoneBridge.instance()?.settings()?.getPreferences() else {
            return
        }
        
        if preferences.pushNotificationsUsePushKit
        {
            pushKitRegistry = PKPushRegistry(queue: DispatchQueue.main)
            pushKitRegistry.desiredPushTypes = [PKPushType.voIP]
            pushKitRegistry.delegate = self
        }
        
        if !preferences.pushNotificationsUsePushKit || preferences.dualPushes
        {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func isRegistrationInActive() -> Bool
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let currentState = SoftphoneBridge.instance()?.registration()?.getRegistrationState(accountId: "sip")
        
        switch currentState
        {
        case RegistratorState_Unregistering:
            return false
            
        case RegistratorState_Registered:
            return false
            
        default:
            return true
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func currentDesiredMedia() -> CallDesiredMedia
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        return CallDesiredMedia.voiceOnly()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func closeTerminalCalls()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        var terminalCalls = [SoftphoneCallEvent]()
        
        let groups = SoftphoneBridge.instance()?.calls()?.conferences()?.list() as! [String]
        
        for groupId in groups
        {
            let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: groupId) as! [SoftphoneCallEvent]
            
            for call in calls
            {
                let callState = SoftphoneBridge.instance()?.calls()?.getState(call)
                if CallState.isTerminal(callState!)
                {
                    terminalCalls.append(call)
                }
            }
        }
        
        for call in terminalCalls
        {
            SoftphoneBridge.instance()?.calls()?.close(call)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// @brief Starts a new call to the given number, with desiredMedia from @ref currentDesiredMedia and through the current
    /// default account
    func call(number: String) -> Bool
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if number.isEmpty {
            return false
        }
        
        let call = SoftphoneCallEvent.create(withAccountId: "sip", uri: number)
        let stream = SoftphoneEventStream.load(SoftphoneStreamQuery.legacyCallHistoryStreamKey())
        
        call?.setStream(stream)
        call?.transients.set("voiceCall", forKey: "dialAction")
        
        let result = SoftphoneBridge.instance()?.events()?.post(call)
        debugPrint(result as Any)
        
        if result == PostResult_Success {
            return true
        }
        
        refreshCallViews()
        return false
    }

    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func playSimulatedMic()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Mutes/unmutes the microphone.
    func toggleMute()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let newMute = (SoftphoneBridge.instance()?.audio()?.isMuted())
        SoftphoneBridge.instance()?.audio()?.setMuted(!newMute!)
        
        refreshCallViews()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Sets speaker mode on/off.
    func toggleSpeaker()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let newSpeaker = SoftphoneBridge.instance()?.audio()?.getCallAudioRoute() != AudioRoute_Speaker
        SoftphoneBridge.instance()?.audio()?.setCallAudioRoute(route: newSpeaker ? AudioRoute_Speaker : AudioRoute_Receiver)
        
        refreshCallViews()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Sets up the SIP account with incoming calls disabled.
    func unregisterAccount()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        sipAccount.setNodeValue(value: "off", name: "icm")
        
        SoftphoneBridge.instance().registration()?.saveAccount(sipAccount)
        SoftphoneBridge.instance().registration()?.updateAll()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Sets up the SIP account with incoming calls enabled.
    func registerAccount()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        sipAccount.setNodeValue(value: "push", name: "icm")
        
        SoftphoneBridge.instance().registration()?.saveAccount(sipAccount)
        SoftphoneBridge.instance().registration()?.updateAll()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func refreshCallViews()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        self.callViewController.refresh()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// @brief Makes the group active/inactive. Inactive group with only one call holds the call, in case there are more calls,
    /// the device microphone is disconnected from the group, but audio is still mixed among the calls in the inactive group
    func toggleActiveGroup(groupId: String)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let wasActive = SoftphoneBridge.instance()?.calls()?.conferences()?.getActive() == groupId
        
        if wasActive
        {
            SoftphoneBridge.instance()?.calls()?.conferences()?.setActive(nil)
        }
        else
        {
            SoftphoneBridge.instance()?.calls()?.conferences()?.setActive(groupId)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func putActiveCallOnHold()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let activeGroupId = SoftphoneBridge.instance()?.calls()?.conferences()?.getActive() else
        {
            return
        }
        
        let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: activeGroupId) as! [SoftphoneCallEvent]
        
        for call in calls
        {
            SoftphoneBridge.instance()?.calls()?.setHeld(call, held: true)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Holds/unholds the specified call.
    func toggleHoldForCall(call: SoftphoneCallEvent)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let holdStates = SoftphoneBridge.instance()?.calls()?.isHeld(call)
        let newHeld = holdStates?.local != CallHoldState_Held
        
        if newHeld
        {
            SoftphoneBridge.instance()?.registration()?.includeNonStandardSipHeader(accountId: "sip",
                                                                                    method: "INVITE",
                                                                                    responseCode: "",
                                                                                    name: "X-HoldCause",
                                                                                    value: "button")
        }
        else
        {
            SoftphoneBridge.instance()?.registration()?.excludeNonStandardSipHeader(accountId: "sip",
                                                                                    method: "INVITE",
                                                                                    responseCode: "",
                                                                                    name: "X-HoldCause")
        }
        
        SoftphoneBridge.instance()?.calls()?.setHeld(call, held: newHeld)
        
        if !newHeld
        {
            let size = SoftphoneBridge.instance()?.calls()?.conferences()?.getSize(call: call)
            
            if size == 1
            {
                // if we are putting a single call off-hold, make its group active to
                // make the microphone output mix-into the conversation, otherwise it
                // doesn't make much sense
                
                SoftphoneBridge.instance()?.calls()?.conferences()?.setActive(call: call)
            }
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// @brief  Answers the specified incoming call, it's callId is typically received via
    /// the @ref Instance::Calls::readIncomingCall, called in the handler of @ref SoftphoneDelegate::softphoneHasIncomingCall
    func answerIncomingCall(call: SoftphoneCallEvent)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let callState = SoftphoneBridge.instance()?.calls()?.getState(call)
        
        if callState != CallState_IncomingRinging && callState != CallState_IncomingIgnored
        {
            return
        }
        
        SoftphoneBridge.instance()?.calls()?.answerIncoming(call: call, media: currentDesiredMedia())
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Rejects the incoming call with Busy
    func rejectIncomingCall(call: SoftphoneCallEvent)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let callState = SoftphoneBridge.instance()?.calls()?.getState(call)
        
        if callState != CallState_IncomingRinging && callState != CallState_IncomingIgnored
        {
            return
        }
        
        SoftphoneBridge.instance()?.calls()?.rejectIncomingHere(call)
        SoftphoneBridge.instance()?.calls()?.close(call)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Hangs up the call with specified callEvent.
    func hangup(call: SoftphoneCallEvent)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        SoftphoneBridge.instance()?.calls()?.close(call)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Hangs up all calls in the specified group.
    func hangupGroup(groupId: String)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: groupId) as! [SoftphoneCallEvent]
        
        for call in calls
        {
            SoftphoneBridge.instance()?.calls()?.close(call)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func getStatistics(call: SoftphoneCallEvent) -> CallStatistics
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        return (SoftphoneBridge.instance()?.calls()?.getStatistics(call))!
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Should be called when the keypad key is touched.
    func dtmfOn(key: Int8)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        SoftphoneBridge.instance()?.audio()?.dtmf(on: key)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Should be called when the keypad key is released.
    func dtmfOff()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        SoftphoneBridge.instance()?.audio()?.dtmfOff()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Gets the current TrafficLog from libsoftphone and dumps it to the console.
    func dumpLog()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let log = SoftphoneBridge.instance()?.log()?.get() ?? ""
        SoftphoneBridge.instance()?.log()?.clear()
        
        debugPrint("=============================================")
        debugPrint(log)
        debugPrint("=============================================")
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Adds the call with callId into an existing group, creating a conference call.
    func joinCall(call: SoftphoneCallEvent, group: String)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        SoftphoneBridge.instance()?.calls()?.conferences()?.move(call: call, conference: group)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Removes the call with callId from a conference and turns it into a separate call.
    func splitCall(call: SoftphoneCallEvent)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        SoftphoneBridge.instance()?.calls()?.conferences()?.split(call: call, activate: true)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// All calls in the group are made single, removing them from any conference call.
    func splitGroup(groupId: String)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: groupId) as! [SoftphoneCallEvent]
        
        for call in calls
        {
            SoftphoneBridge.instance()?.calls()?.conferences()?.split(call: call, activate: false)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Transfers the call to a number which is currently filled in in @ref RegViewController
    func transferCall(call: SoftphoneCallEvent)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if self.regViewController.number.text?.count == 0
        {
            return
        }
        
        let newCall = SoftphoneCallEvent.create(withAccountId: "sip", uri: self.regViewController.number.text)
        let stream = SoftphoneEventStream.load(SoftphoneStreamQuery.legacyCallHistoryStreamKey())
        
        newCall?.setStream(stream)
        
        SoftphoneBridge.instance()?.calls()?.conferences()?.transfer(call: call, target: newCall)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Attended transfsfer the call with callId into otherCall
    func attendedTransfer(from: SoftphoneCallEvent, to: SoftphoneCallEvent)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        SoftphoneBridge.instance()?.calls()?.conferences()?.attendedTransfer(call: from, target: to)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// Sends an example text message to the recipient, using the currently configured account.
    func sendExampleSMS(recipient: String)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if recipient.count == 0
        {
            return
        }
        
        let defaultAccount = "sip"
        
        let party = SoftphoneStreamParty()
        party.setCurrentTransportUri(recipient)
        party.match(defaultAccount)
        
        let message = SoftphoneMessageEvent()
        message.body = "TEST MESSAGE"
        message.addRemoteUser(SoftphoneRemoteUser(streamParty: party))
        message.setAccount(defaultAccount)
        
        let result = SoftphoneBridge.instance()?.events()?.post(message)
        debugPrint(result as Any)
        
        if result != PostResult_Success
        {
            // report failure
            return;
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func sendExampleSMSWithAttachment(recipient: String)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if recipient.count == 0
        {
            return
        }
        
        guard let image = UIImage(named: "MessageAttachment") else {
            return
        }
        
        guard let att = SoftphoneEventAttachment(contentType: "image/jpeg", path: "") else {
            return
        }
        
        store(image: image, attachment: att, purpose: .payload)
        store(image: image, attachment: att, purpose: .networkPreview)
        store(image: image, attachment: att, purpose: .localPreview)
        
        let defaultAccount = "sip"
        
        let party = SoftphoneStreamParty()
        party.setCurrentTransportUri(recipient)
        party.match(defaultAccount)
        
        let message = SoftphoneMessageEvent()
        message.body = "TEST MESSAGE WITH ATTACHMENT"
        message.addRemoteUser(SoftphoneRemoteUser(streamParty: party))
        message.setAccount(defaultAccount)
        
        message.addAttachment(attachment: att)
        
        let result = SoftphoneBridge.instance()?.events()?.post(message)
        debugPrint(result as Any)
        
        if result != PostResult_Success
        {
            // report failure
            return;
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func store(image: UIImage, attachment: SoftphoneEventAttachment, purpose: ImagePurpose)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        var data: Data
        let fileId = "att_" + UUID().uuidString
        
        switch purpose
        {
        case .payload:
            data = image.jpegData(compressionQuality: 0.9)!
        
        case .localPreview, .temporaryLocalPreview:
            data = image.jpegData(compressionQuality: 0.5)!
        
        case .networkPreview:
            data = image.jpegData(compressionQuality: 0)!
        }
        
        var filePath = ""
        var pathWithoutFileName = ""
        
        if purpose == .payload
        {
            pathWithoutFileName = filePath.appending("%data%")
        }
        else
        {
            pathWithoutFileName = filePath.appending("%previews%")
        }
        
        filePath = pathWithoutFileName.appending("/")
        filePath = filePath.appending(fileId)
        filePath = filePath.appending(".jpg")
        
        let toPath = SoftphoneEventAttachment.expandPath(filePath)
        let toPathWithoutFileName = SoftphoneEventAttachment.expandPath(pathWithoutFileName)
        
        if !FileManager.default.fileExists(atPath: toPathWithoutFileName!)
        {
            do
            {
                try FileManager.default.createDirectory(atPath: toPathWithoutFileName!,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            }
            catch
            {
                return
            }
        }
        
        do
        {
            let u = URL(fileURLWithPath: toPath!)
            try data.write(to: u, options: .atomic)
        }
        catch
        {
            return
        }
        
        switch purpose
        {
        case .payload:
            attachment.contentPath = filePath
            
        case .localPreview:
            attachment.localThumbnailPath = filePath
            
        case .networkPreview, .temporaryLocalPreview:
            attachment.networkThumbnailPath = filePath
        }
    }
    
    private func showMissedCallNotification(call: SoftphoneCallEvent) {
        let content = UNMutableNotificationContent()
        content.title = call.getRemoteUser(index: 0).displayName
        content.body = "Missed Call"
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugPrint("Notification request error: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadXMLFileAsString(atPath path: String) -> String? {
        do {
            let xmlString = try String(contentsOfFile: path, encoding: .utf8)
            return xmlString
        } catch {
            debugPrint("Error loading XML file: \(error)")
            return nil
        }
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension AppDelegate: UIApplicationDelegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func startSoftphoneSdk()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if sdkState == .running {
            return
        }
        
        guard let filePath = Bundle.main.path(forResource: "provisioning", ofType: "xml") else {
            debugPrint("Provisioning file is missing")
            return
        }
        
        guard let xmlString = loadXMLFileAsString(atPath: filePath) else {
            debugPrint("Error while loading provisioning profile")
            return
        }
        
        let sip_account = """
                    <account id=\"sip\">
                        <title>Sip Account</title>
                        <username>1125</username>
                        <password>misscom</password>
                        <host>pbx.acrobits.cz</host>
                        <icm>push</icm>
                        <transport>udp</transport>
                        <codecOrder>0,8,9,3,102</codecOrder>
                        <codecOrder3G>102,3,9,0,8</codecOrder3G>
                    </account>
        """
        
        do {
            try SoftphoneBridge.initialize(xmlString)
            let softphoneInstance = SoftphoneBridge.instance()
            
            softphoneInstance?.log()?.setCustomSink(serializer)
            softphoneInstance?.settings()?.getPreferences()?.trafficLogging = true
            
            softphoneObserverProxy = SoftphoneObserverProxyBridge()
            softphoneObserverProxy.delegate = self;
            softphoneInstance?.setObserver(softphoneObserverProxy)
            
            sipAccount = XmlTree.parse(sip_account)
            
            let s = sipAccount?.toString(true);
            debugPrint("Account XML: \(s!)");
            
            softphoneInstance?.registration()?.saveAccount(sipAccount)
            softphoneInstance?.registration()?.updateAll()
            
            Softphone_Cx.instance()?.delegate = self
            
            sdkState = .running
        }
        catch let error as NSError {
            if error.domain == LicensingManagementErrorDomain {
                if let errorCode = LicensingManagementErrorCode(rawValue: error.code) {
                    switch errorCode {
                    case .LicenseInvalid:
                        debugPrint("Invalid license")
                    case .LicenseMissing:
                        debugPrint("Missing license")
                    @unknown default:
                        debugPrint(error);
                    }
                }
            }
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func stopSoftphoneSdk(_ callback:(() -> Void)?)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if sdkState == .stopped {
            return
        }
        
        if callback != nil {
            terminatingCallbacks.append(callback!)
        }
        
        if terminatingTimer != nil {
            return
        }
        
        sdkState = .terminating
        SoftphoneBridge.instance().state().terminate()
        
        terminatingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] timer in
            if !SoftphoneBridge.instance().state().isTerminated() {
                return
            }
            
            sdkState = .stopped
            terminatingTimer?.invalidate()
            terminatingTimer = nil
            
            softphoneObserverProxy.delegate = nil
            SoftphoneBridge.deinit()
            
            terminatingCallbacks.forEach { callback in
                callback()
            }
            
            terminatingCallbacks.removeAll()
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        startSoftphoneSdk()
        
        let tabController = self.window?.rootViewController as! UITabBarController
        regViewController = tabController.viewControllers![0] as? RegViewController
        callViewController = tabController.viewControllers![1] as? CallViewController
        
        _ = regViewController.view
        _ = callViewController.view
        
        refreshCallViews()
        
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.badge, .sound, .alert]) { granted, error in
            if granted {
                debugPrint("\n\nUser Notification authorization granted\n")
            } else {
                debugPrint("\n\nUser Notification authorization denied\n")
            }
        }

        
        regViewController.username.text = sipAccount.getValueForNode("username")
        
        registerForPushNotifications()
                
//        let a1 = ["username" : "1080",
//                  "password" : "misscom",
//                  "host" : "pbx.acrobits.cz"]
//        
//        let dict = ["account" : a1]
//        
//        let x = Dictionary<AnyHashable, Any>.xmlFromDictionary(dict)
//        debugPrint(x.toString(true)!)

        return true
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func applicationDidBecomeActive(_ application: UIApplication)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func applicationWillResignActive(_ application: UIApplication)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func applicationDidEnterBackground(_ application: UIApplication)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func applicationWillEnterForeground(_ application: UIApplication)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func applicationWillTerminate(_ application: UIApplication)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        debugPrint("Got remote-notification token")
        
        guard let dualPushes = SoftphoneBridge.instance()?.settings()?.getPreferences().dualPushes else {
            return
        }
        
        let usage = dualPushes ? PushTokenUsage_Other : PushTokenUsage_All
        SoftphoneBridge.instance()?.notifications()?.push()?.setRegistrationId(token: deviceToken, usage: usage)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        debugPrint("Did fail to get remote-notification token")
        
        let usage = (SoftphoneBridge.instance()?.settings()?.getPreferences().dualPushes)! ? PushTokenUsage_Other : PushTokenUsage_All
        
        SoftphoneBridge.instance()?.notifications()?.push()?.setRegistrationId(token: nil, usage: usage)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        debugPrint("Got remote-notification push")
        startSoftphoneSdk()
        
        let identifier = UUID().uuidString
        
        let xml = Dictionary<AnyHashable, Any>.xmlFromDictionary(userInfo)
        debugPrint("XML: \(String(describing: xml.toString(true)))")
        
        let handle = SoftphoneBridge.instance()?.notifications()?.push()?.handle(xml, usage: PushTokenUsage_Other, completion: { (info) in
            
            switch info?.result
            {
            case PushNotificationCompletionInfoResult_NewData:
                completionHandler(UIBackgroundFetchResult.newData)
                
            case PushNotificationCompletionInfoResult_NoData:
                completionHandler(UIBackgroundFetchResult.noData)
                
            case PushNotificationCompletionInfoResult_Failed:
                completionHandler(UIBackgroundFetchResult.failed)
                
            default:
                completionHandler(UIBackgroundFetchResult.failed)
            }
            
            self.pushHandles.removeValue(forKey: identifier)
        })
        
        self.pushHandles[identifier] = handle
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension AppDelegate: UNUserNotificationCenterDelegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        completionHandler([.badge, .sound, .banner])
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension AppDelegate: SoftphoneDelegateBridge
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onMissedCalls(_ callEvents: [SoftphoneCallEvent]!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        for call in callEvents {
            showMissedCallNotification(call: call)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onPushTestScheduled(accountId: String!, result: PushTestScheduleResultType)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onPushTestArrived(_ accountId: String!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func getRingtonePath(_ call: SoftphoneCallEvent!) -> String!
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        var resourcePath = Bundle.main.resourcePath;
        resourcePath?.append("/dm.wav")
        
        return resourcePath
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onComposingInfo(_ info: SoftphoneMessagingComposingInfo!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onDialogEvent(accountId: String!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onVoicemail(voicemail: VoicemailRecord!, accountId: String!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onBalance(balance: BalanceRecord!, accountId: String!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onEventsChanged(events: SoftphoneChangedEvents!, streams: SoftphoneChangedStreams!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        refreshCallViews()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onMediaStatusChanged(media: CallMediaStatus!, call: SoftphoneCallEvent!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        refreshCallViews()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onCallRepositoryChanged()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        refreshCallViews()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onRegistrationStateChanged(state: RegistratorStateType, accountId: String!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        regViewController.regState.text = RegistratorState.toString(state)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onRegistrationStateChanged(state: RegistratorStateType)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        debugPrint("[SP] onRegistrationStateChanged:\(state.rawValue)")
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onNetworkChangeDetected(_ network: NetworkType)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        debugPrint("[SP] onNetworkChangeDetected")
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onNewEvent(_ event: SoftphoneEvent!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if event.isCall()
        {
            closeTerminalCalls()
            refreshCallViews()
        }
        else
        {
            let message = event.asMessage()
            
            let alert = UIAlertController(title: "Message", message: message?.body, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.window?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onCallStateChanged(state: CallStateType, call: SoftphoneCallEvent!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        refreshCallViews()
        closeTerminalCalls()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onHoldStateChanged(states: CallHoldStates!, call: SoftphoneCallEvent!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        refreshCallViews()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onAudioRouteChanged(_ route: AudioRouteType)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        refreshCallViews()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func onNetworkCertificateVerificationFailed(host: String!, certificateHash: String!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if securityAlerts[host] == nil
        {
            let alert = UIAlertController(title: "Security Warning", message: "The certificate for domain \(host ?? "") is not valid or has expired", preferredStyle: .alert);
            
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                self.securityAlerts.removeValue(forKey: host)
            }))
            
            alert.addAction(UIAlertAction(title: "Trust", style: .default, handler: { _ in
                SoftphoneBridge.instance().network().certificates().addException(host: host, hash: certificateHash)
                self.securityAlerts.removeValue(forKey: host)
            }))
            
            securityAlerts[host] = alert
            self.window?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension AppDelegate: PKPushRegistryDelegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let dualPushes = SoftphoneBridge.instance()?.settings()?.getPreferences().dualPushes else {
            return
        }
        
        let usage = dualPushes ? PushTokenUsage_IncomingCall : PushTokenUsage_All
        SoftphoneBridge.instance()?.notifications()?.push()?.setRegistrationId(token: pushCredentials.token, usage: usage)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        startSoftphoneSdk()
        
        let xml = Dictionary<AnyHashable, Any>.xmlFromDictionary(payload.dictionaryPayload)
        debugPrint("XML: \(String(describing: xml.toString(true)))")
        
        SoftphoneBridge.instance()?.notifications()?.push()?.handle(xml, usage: PushTokenUsage_IncomingCall, completion: nil)
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension AppDelegate: Softphone_Cx_Delegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func cxCallUpdate(_ callUpdate: CXCallUpdate!, forCall call: SoftphoneCallEvent!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension UIAlertController
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func show()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        UIApplication.shared.keyWindow?.rootViewController?.present(self, animated: true)
    }
}
