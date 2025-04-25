//
//  RegistrationServices.swift
//  SwiftPhone
//
//  Created by Diego on 13.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import Foundation
import Combine
import Softphone_Swift

class RegistrationService {
    
    var account: CurrentValueSubject<XmlTree?, Never> = .init(nil)
    var state: CurrentValueSubject<RegistratorStateType, Never> = .init(RegistratorState_None)
    
    private var onCall: PassthroughSubject<Void, Never> = .init()
    
    func registerAccount() {
        AppDelegate.theApp().registerAccount()
    }
    
    func unregisterAccount() {
        AppDelegate.theApp().unregisterAccount()
    }
    
    func stopSDK(completion: @escaping () -> Void) {
        AppDelegate.theApp().stopSoftphoneSdk {
            completion()
        }
    }
    
    func startSDK(completion: @escaping () -> Void) {
        AppDelegate.theApp().startSoftphoneSdk()
        completion()
    }
    
    func dumpLog() {
        AppDelegate.theApp().dumpLog()
    }
}
