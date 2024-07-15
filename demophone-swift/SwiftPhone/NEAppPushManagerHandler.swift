import Foundation
import NetworkExtension
import Combine

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
class NEAppPushManagerHandler : NSObject
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    static let instance = NEAppPushManagerHandler()
    private var pushManager: NEAppPushManager?
    private var pushConfig: NEAppPushManagerConfig?
    
    private let incomingCallSubject = PassthroughSubject<([AnyHashable : Any]), Never>()
    private let pushManagerIsActiveSubject = CurrentValueSubject<Bool, Never>(false)
    
    lazy var incomingCallPublisher = incomingCallSubject.eraseToAnyPublisher()
    lazy var pushManagerIsActivePublisher = pushManagerIsActiveSubject.eraseToAnyPublisher()
    
    private var pushManagerIsActiveCancellable: AnyCancellable?
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private override init()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        super.init()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func initialize(completion: ((Error?) -> Void)? = nil)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        NEAppPushManager.loadAllFromPreferences { [weak self] managers, error in
            precondition(Thread.isMainThread)
            
            guard let self else { return }
            
            var appPushManager: NEAppPushManager?
            if let error = error {
                print("[NEPushManagerHandler] Error loading all from preferences: \(error)")
            }
            else {
                if let managers = managers {
                    for manager in managers {
                        if manager.isEnabled {
                            appPushManager = manager
                        }
                    }
                }
                
                if let appPushManager = appPushManager {
                    pushManager = appPushManager
                    pushConfig = NEAppPushManagerConfig(manager: appPushManager)
                    appPushManager.isEnabled = true
                    appPushManager.delegate = self
                    
                    pushManagerIsActiveCancellable = NSObject.KeyValueObservingPublisher(object: appPushManager, keyPath: \.isActive, options: [.new]).subscribe(pushManagerIsActiveSubject)
                }
            }
            completion?(error)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func update(config: NEAppPushManagerConfig, completion: ((Error?) -> Void)? = nil)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if pushConfig == config {
            completion?(nil)
            return
        }
        
        pushConfig = config
        
        if pushManager == nil {
            pushManager = NEAppPushManager()
            pushManager?.providerBundleIdentifier = "cz.acrobits.softphone.demophone.networkExt"
            pushManager?.localizedDescription = "Demophone App Push Manager"
            pushManager?.delegate = self
            pushManager?.isEnabled = true
            pushManagerIsActiveCancellable = NSObject.KeyValueObservingPublisher(object: pushManager!, keyPath: \.isActive, options: [.new]).subscribe(pushManagerIsActiveSubject)
        }
        
        pushManager?.matchSSIDs = config.matchSSIDs
        pushManager?.providerConfiguration = [
            "sendKeepAlives": config.sendKeepAlives,
            "keepAliveInterval": config.keepAliveInterval,
            "listeningPort": config.listeningPort,
            "httpListeningPort": config.httpListeningPort,
            "adminUsername": config.adminUsername,
            "adminPassword": config.adminPassword,
            "checksums": config.checksums,
            "postData": config.postData
        ]
        
        savePushManagerPreferences(reload: true, completion: completion)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func savePushManagerPreferences(reload: Bool = false, completion: ((Error?) -> Void)? = nil)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        pushManager?.saveToPreferences(completionHandler: { [weak self] error in
            precondition(Thread.isMainThread)
            
            guard let self else  { return }
            
            if let error = error {
                print("[NEPushManagerHandler] Error while saving to preferences: \(error)")
            }
            else {
                print("[NEPushManagerHandler] Push manager preferences saved successfully")
                if reload {
                    loadPushManagerPreferences(completion: completion)
                    return
                }
            }
            completion?(error)
        })
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func loadPushManagerPreferences(completion: ((Error?) -> Void)? = nil)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        pushManager?.loadFromPreferences(completionHandler: { error in
            precondition(Thread.isMainThread)
            
            if let error = error {
                print("[NEPushManagerHandler] Error loading preferences: \(error)")
            }
            else {
                print("[NEPushManagerHandler] Push manager preferences loaded successfully")
            }
            completion?(error)
        })
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    deinit
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        pushManager?.removeObserver(self, forKeyPath: #keyPath(NEAppPushManager.isActive))
    }
}

// MARK: - NEAppPushDelegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension NEAppPushManagerHandler : NEAppPushDelegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func appPushManager(_ manager: NEAppPushManager, didReceiveIncomingCallWithUserInfo userInfo: [AnyHashable : Any] = [:])
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        // Handle incoming call information
        print("[NEPushManagerHandler] Received incoming call user info: \(userInfo)")
        incomingCallSubject.send(userInfo)
    }
}
