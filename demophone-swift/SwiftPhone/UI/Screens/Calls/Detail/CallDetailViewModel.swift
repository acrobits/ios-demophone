//
//  UserCallViewModel.swift
//  SwiftPhone
//
//  Created by Diego on 14.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

enum ActionButton: String, Identifiable {
    case hold
    case hangup
    case speaker
    case mute
    case transfer
    case answer
    case attendedTransfer
    case join
    case reject
    case split
    case command
    
    var id: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .hold: return "pause"
        case .hangup: return "phone.down.fill"
        case .speaker: return "speaker.fill"
        case .mute: return "speaker.slash.fill"
        case .transfer: return "arrow.uturn.right"
        case .answer: return "phone.fill"
        case .attendedTransfer: return "arrow.left.arrow.right"
        case .join: return "arrow.trianglehead.merge"
        case .reject: return "xmark"
        case .split: return "arrow.trianglehead.branch"
        case .command: return "command"
        }
    }
    
    var title: String {
        switch self {
        case .hold: return "Hold"
        case .hangup: return "Hangup"
        case .speaker: return "Speaker"
        case .mute: return "Mute"
        case .transfer: return "Transfer"
        case .answer: return "Answer"
        case .attendedTransfer: return "Att. Transfer"
        case .join: return "Join"
        case .reject: return "Reject"
        case .split: return "Split"
        case .command: return "*"
        }
    }
    
    var isDestroyStyle: Bool {
        switch self {
        case .hangup, .reject:
            return true
        default:
            return false
        }
    }
    
    var isAcceptStyle: Bool {
        return self == .answer
    }
    
    var isRegularStyle: Bool {
        return !self.isDestroyStyle && !self.isAcceptStyle
    }
    
    var isToggleable: Bool {
        return [
            ActionButton.hold,
            .mute,
            .speaker
        ].contains { $0 == self }
    }
}

enum CallInputType: String, Identifiable {
    case transfer
    case join
    case attendedTransferPick
    case attendedTransferNew
    
    var id: String {
        return self.rawValue
    }
}


class CallDetailViewModel: ObservableObject {
    
    @Published var callItem: ActiveCallItem
    @Published var isOnHold = false
    @Published var isMuteOn = false
    @Published var isSpeakerOn = false
    @Published var selectCallPicker: CallInputType?
    @Published var transferNumber: String = ""
    @Published var confirmAlert = false
    @Published var speakerSelected = false
    
    var accountName: String {
        return callItem.account
    }
    
    var status: String {
        if isOnHold {
            return "\(callItem.status) (On Hold)"
        } else {
            return callItem.status
        }
    }
    
    var gridButtons: [ActionButton] {
        if callItem.canBeAnswered {
            return []
        } else {
            return [ .transfer, .attendedTransfer, .join, .split, .command, .speaker ]
        }
    }
    
    var lowerButtons: [ActionButton] {
        if callItem.canBeAnswered {
            return [.answer, .reject]
        } else {
            return [.mute, .hangup, .hold]
        }
    }

    private let audioPickerProxy = AudioRoutePickerProxy()
    
    private var callEvent: SoftphoneCallEvent? {
        let call: SoftphoneCallEvent?
        
        if callItem.entry.isGroup() {
            call = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: callItem.entry.groupId).first
        } else {
            call = callItem.entry.call
        }
        
        guard let call = call else {
            return nil
        }
        
        return call
    }
    
    private var cancellable = Set<AnyCancellable>()
    private var callService: CallService
    
    init(callItem: ActiveCallItem) {
        self.callItem = callItem
        self.isOnHold = callItem.isOnHold
        self.callService = AppDelegate.theApp().callService
        
        self.callService
            .onDismissSelectedCall
            .sink { [weak self] _ in
                self?.selectCallPicker = nil
            }
            .store(in: &cancellable)
        
        self.callService
            .onConfirmAttendedTransfer
            .sink { [weak self] _ in
                self?.confirmAlert = true
            }
            .store(in: &cancellable)
    }
    
    func hangupCall() {
        callService.hangupCall(callItem.entry)
    }
    
    func holdCall() {
        callService.holdCall(callItem.entry)
    }
    
    func muteCall() {
        callService.muteCall()
    }
    
    func toggleSpeaker() {
        if audioPickerProxy.wirelessRoutesAvailable {
            speakerSelected = true
        } else {
            speakerSelected = false
            callService.activateSpeaker()
        }
    }
    
    func showTransferCall() {
        selectCallPicker = .transfer
        callService.transfer(entry: callItem.entry)
    }
    
    func transferCall() {
        selectCallPicker = nil
        callService.startCall(number: transferNumber, dialAction: "")
    }
    
    /**
     1. CallDetailView taps att. transfer
     2. CallDetailViewModel calls the service and checks what att type is it. Also it sets the source call of the transfer
     3. Depending on the att.transfer type the next actions goes:
        3.1. direct calls the transfer method with call + first one in the attended call list. Transfer starts and all ends.
        3.2. new call, opens the enter call input.
            3.2.1. Will open the transfer call with input (maybe change the button title to create call).
            3.2.2. Once the new call is created, the modals are dismissed. If the user selects the call again, the att. transfer should call the direct case now. (Go to 3.1)
        3.3. pick call, opens the select call picker with the list of attended calls available.
            3.3.1. Will open the call picker, needs the call of att. transfer calls passed as a param (also is set as att transfer mode)
            3.3.2. Call is selected from the list, call service method is called and transfer is finished. All modals are dismissed.
     4. When the target is selected, a confirmation alert will be presented.
        4.1 if confirmed, complete the transfer
        4.2 if cancelled, cancel the transfer
     */
    
    func showAttendedTransferCall() {
        guard let transferType = callService.startAttendedCall(entry: callItem.entry) else {
            return
        }
        
        switch transferType {
        case .direct:
            break
        case .newCall:
            selectCallPicker = .attendedTransferNew
        case .pickCall:
            selectCallPicker = .attendedTransferPick
        }
    }
    
    func startAttendedTransferWithSelectedCall(entry: Entry) {
        callService.startAttendedTransferWithSelectedCall(entry: entry)
    }
    
    func attendedTransferCall() {
    }
    
    func showJoin() {
        selectCallPicker = .join
    }
    
    func startJoin(entry: Entry) {
        callService.join(entry)
    }
    
    func split() {
        callService.split(callItem.entry)
    }
    
    func answer() {
        callService.answer(callItem.entry)
    }
    
    func reject() {
        callService.reject(callItem.entry)
    }
    
    func getEntriesForSelection(type: CallInputType) -> [Entry] {
        switch type {
        case .join:
            return callService
                .singleCallEntries
                .filter { [unowned self] entry -> Bool in
                    if let selectedCall = self.callItem.entry.call {
                        return selectedCall != entry.call
                    } else if let entryCall = entry.call {
                        let groupOfCall = SoftphoneBridge.instance()?.calls().conferences().get(entryCall)
                        return groupOfCall != self.callItem.entry.groupId
                    } else {
                        return true
                    }
                }
        case .attendedTransferPick:
            return callService.attTransferCallEntries
        case .transfer, .attendedTransferNew:
            return []
        }
    }
    
    func onCallSelection(entry: Entry, type: CallInputType) {
        if type == .join {
            startJoin(entry: entry)
        } else if type == .attendedTransferPick {
            startAttendedTransferWithSelectedCall(entry: entry)
        }
    }
    
    func onCallInput(type: CallInputType) {
        transferCall()
    }
    
    func dismissInput() {
        selectCallPicker = nil
    }
    
    func confirmAttendedTransfer() {
        callService.finishAttendedTransfer()
    }
    
    func cancelAttendedTransfer() {
        callService.cancelAttendedTransfer()
    }
}
