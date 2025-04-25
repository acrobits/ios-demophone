//
//  CallViewModel.swift
//  SwiftPhone
//
//  Created by Diego on 13.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

struct ActiveCallItem: Identifiable, Equatable {
    let id = UUID()
    let account: String
    let status: String
    let incoming: Bool
    let canBeAnswered: Bool
    let duration: String?
    let isOnHold: Bool
    let entry: Entry
    
    static func == (lhs: ActiveCallItem, rhs: ActiveCallItem) -> Bool {
        return lhs.id == rhs.id
    }
}

class CallListViewModel: ObservableObject {
    
    @Published var selectedCall: ActiveCallItem?
    @Published var callList: [ActiveCallItem] = []
    
    var outgoingCalls: [ActiveCallItem] = []
    var incomingCalls: [ActiveCallItem] = []

    private var currentCallCount = 0
    private var callService: CallService
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.callService = AppDelegate.theApp().callService
        
        self.callService
            .onCallEntriesUpdate
            .compactMap { [weak self] entries -> [ActiveCallItem]? in
                guard !entries.isEmpty else {
                    return []
                }
                
                return self?.mapEntriesToCallItem(entries)
            }
            .sink(receiveValue: { [weak self] calls in
                self?.callList = calls
                self?.incomingCalls = calls.filter { $0.incoming }
                self?.outgoingCalls = calls.filter { !$0.incoming }
            })
            .store(in: &cancellables)
        
        self.callService
            .onDismissSelectedCall
            .sink { [weak self] _ in
                self?.selectedCall = nil
            }
            .store(in: &cancellables)
        
        self.callService
            .onOpenActiveCall
            .sink { [weak self] entry in
                guard let sself = self else { return }
                let item = sself.callList.first { $0.entry == entry }
                guard let item = item else { return }
                self?.selectedCall = item
            }
            .store(in: &cancellables)
    }
    
    func mapEntriesToCallItem(_ entries: [Entry]) -> [ActiveCallItem] {
        var items: [ActiveCallItem] = []
        
        for entry in entries {
            if entry.isGroup() {
                let active = SoftphoneBridge.instance()?.calls()?.conferences()?.getActive() == entry.groupId // checking if the conference is OnHold or not
                
                let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: entry.groupId)

                let size = SoftphoneBridge.instance()?.calls()?.conferences()?.getSize(entry.groupId)
                
                guard let size = size else {
                    continue
                }
                
                let title: String
                var status: String
                var incoming = isIncomingState(call: calls?.first)
                let canBeAnswered = canBeAnswered(call: calls?.first)
                
                if let call = calls?.first, size == 1 {
                    title = "Call: \(call.getRemoteUser(index: 0).displayName ?? "")"
                    incoming = isIncomingState(call: call)
                    status = CallState.toString(SoftphoneBridge.instance().calls().getState(call))
                } else if let call = calls?.first, size > 1 {
                    title = "Group call: \(size) Participants"
                    status = CallState.toString(SoftphoneBridge.instance().calls().getState(call))
                } else {
                    title = "Call"
                    status = "Active"
                }

                let item = ActiveCallItem(account: title,
                                          status: status,
                                          incoming: incoming,
                                          canBeAnswered: canBeAnswered,
                                          duration: nil,
                                          isOnHold: !active,
                                          entry: entry)

                items.append(item)
            } else {
                var isOnHold = false
                if let holdStates = SoftphoneBridge.instance().calls().isHeld(entry.call) {
                    isOnHold = holdStates.local == CallHoldState_Held
                }

                let title = "Call: \(entry.call?.getRemoteUser(index: 0)?.displayName! ?? "")"
                let status = CallState.toString((SoftphoneBridge.instance()?.calls()?.getState(entry.call))!) ?? "Active"
                
                let item = ActiveCallItem(account: title,
                                          status: status,
                                          incoming: isIncomingState(call: entry.call),
                                          canBeAnswered: canBeAnswered(call: entry.call),
                                          duration: nil,
                                          isOnHold: isOnHold,
                                          entry: entry)
//
                items.append(item)
            }
        }
        
        return items
    }
    
    private func isIncomingState(call: SoftphoneCallEvent?) -> Bool {
        guard let call = call else {
            return false
        }
        
        guard let state = SoftphoneBridge.instance()?.calls()?.getState(call) else {
            return false
        }
        
        return [
            CallState_IncomingAnswered,
            CallState_IncomingTrying,
            CallState_IncomingRinging,
            CallState_IncomingIgnored,
            CallState_IncomingRejected,
            CallState_IncomingMissed,
            CallState_IncomingForwarded,
            CallState_IncomingAnsweredElsewhere
        ].contains { $0 == state }
    }
    
    private func canBeAnswered(call: SoftphoneCallEvent?) -> Bool {
        guard let call = call else {
            return false
        }
        
        guard let callState = SoftphoneBridge.instance()?.calls()?.getState(call) else {
            return false
        }
        
        return callState == CallState_IncomingRinging || callState == CallState_IncomingIgnored
    }
}
