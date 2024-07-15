import Foundation

extension Bundle {
    static var appBundle: Bundle {
        var bundle = Bundle.main
        if bundle.bundleURL.pathExtension == "appex" {
            // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
            if let url = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent() as URL? {
                if let parentBundle = Bundle(url: url) {
                    bundle = parentBundle
                }
            }
        }
        return bundle
    }

    static var sharedAppGroupId: String? {
        return appBundle.object(forInfoDictionaryKey: "SHARED_APP_GROUP_ID") as? String
    }
}

