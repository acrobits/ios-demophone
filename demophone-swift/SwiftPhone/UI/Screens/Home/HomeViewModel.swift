//
//  HomeViewModel.swift
//  SwiftPhone
//
//  Created by Diego on 13.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    
    @Published var activeCallExists = false
    @Published var selectedTab = 1
    @Published var showAlert = false
    
    var alertMessage = ""
    
    private var callService: CallService
    private var cancellable = Set<AnyCancellable>()
    
    init() {
        self.callService = AppDelegate.theApp().callService
        
        self.callService
            .onCallStarted
            .sink { [weak self] in
                self?.selectedTab = 2
            }
            .store(in: &cancellable)
        
        self.callService
            .onActiveCallChanged
            .sink { [weak self] entry in
                self?.activeCallExists = entry != nil
            }
            .store(in: &cancellable)
        
        self.callService
            .onError
            .sink { [weak self] error in
                if error.isEmpty {
                    self?.alertMessage = ""
                    self?.showAlert = false
                } else {
                    self?.alertMessage = error
                    self?.showAlert = true
                }
            }
            .store(in: &cancellable)
    }
    
    func openActiveCall() {
        selectedTab = 2
        callService.openActiveCall()
    }
}
