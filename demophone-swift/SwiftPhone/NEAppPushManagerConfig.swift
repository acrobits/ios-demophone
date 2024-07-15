import Foundation
import NetworkExtension

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
class NEAppPushManagerConfig : Equatable
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    var matchSSIDs: [String]
    var keepAliveInterval: Int
    var listeningPort: Int
    var httpListeningPort: Int
    var sendKeepAlives: Bool
    var adminUsername: String
    var adminPassword: String
    var checksums: [String]
    var postData: [String]
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    init()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        self.matchSSIDs = []
        self.keepAliveInterval = 0
        self.listeningPort = 0
        self.httpListeningPort = 0
        self.sendKeepAlives = false
        self.adminUsername = ""
        self.adminPassword = ""
        self.checksums = []
        self.postData = []
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    init(manager: NEAppPushManager)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let dict = manager.providerConfiguration
        self.keepAliveInterval = dict["keepAliveInterval"] as? Int ??  0
        self.listeningPort = dict["listeningPort"] as? Int ?? 0
        self.httpListeningPort = dict["httpListeningPort"] as? Int ?? 0
        self.sendKeepAlives = dict["sendKeepAlives"] as? Bool ?? false
        self.adminUsername = dict["adminUsername"] as? String ?? ""
        self.adminPassword = dict["adminPassword"] as? String ?? ""
        self.checksums = dict["checksums"] as? [String] ?? []
        self.postData = dict["postData"] as? [String] ?? []
        self.matchSSIDs = manager.matchSSIDs
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    static func == (lhs: NEAppPushManagerConfig, rhs: NEAppPushManagerConfig) -> Bool
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        return lhs.matchSSIDs == rhs.matchSSIDs &&
        lhs.keepAliveInterval == rhs.keepAliveInterval &&
        lhs.listeningPort == rhs.listeningPort &&
        lhs.httpListeningPort == rhs.httpListeningPort &&
        lhs.sendKeepAlives == rhs.sendKeepAlives &&
        lhs.adminUsername == rhs.adminUsername &&
        lhs.adminPassword == rhs.adminPassword &&
        lhs.checksums == rhs.checksums
    }
}
