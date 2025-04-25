//
//  UserRegistrationViewModel.swift
//  SwiftPhone
//
//  Created by Diego on 13.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

class UserRegistrationViewModel: ObservableObject {
    
    @Published var userAccount: String = ""
    @Published var registeredAccount = true
    @Published var state: String = ""
    @Published var numberForCall: String = ""
    @Published var isSDKActive = true
    @Published var isSDKButtonEnabled = true
    
    var hideRegistered = true
    
    private var callService: CallService
    private var registrationService: RegistrationService
    private var subscription = Set<AnyCancellable>()
    
    init() {
        self.registrationService = AppDelegate.theApp().registrationService
        self.callService = AppDelegate.theApp().callService
        
        let sdkState = AppDelegate.theApp().sdkState == .running
        self.isSDKActive = sdkState
        
        self.registrationService.account
            .compactMap { account -> String? in
                guard let account = account else {
                    return nil
                }
                
                return account.getValueForNode("username")
            }
            .sink { [weak self] account in
                self?.userAccount = account
            }
            .store(in: &subscription)
        
        self.registrationService.state
            .map { type -> String in
                return RegistratorState.toString(type)
            }
            .assign(to: &$state)
        
        $registeredAccount
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] isRegistered in
                if isRegistered {
                    self?.registerAccount()
                } else {
                    self?.unregisterAccount()
                }
            }
            .store(in: &subscription)
    }
    
    func registerAccount() {
        registrationService.registerAccount()
    }
    
    func unregisterAccount() {
        registrationService.unregisterAccount()
    }
    
    func startCall() {
        if !numberForCall.isEmpty {
            callService.startCall(number: self.numberForCall)
        }
    }
    
    func sendSms() {
        if !numberForCall.isEmpty {
            callService.sendSms(number: self.numberForCall)
        }
    }
    
    func sendSmsAttachment() {
        if !numberForCall.isEmpty {
            callService.sendSmsAttachment(number: self.numberForCall)
        }
    }
    
    func dumpLog() {
        registrationService.dumpLog()
    }
    
    func toogleSDK() {
        isSDKButtonEnabled = false
        
        if (isSDKActive) {
            registrationService.stopSDK { [weak self] in
                self?.isSDKButtonEnabled = true
            }
        } else {
            registrationService.startSDK { [weak self] in
                self?.isSDKButtonEnabled = true
            }
        }
        
        isSDKActive.toggle()
    }
}
