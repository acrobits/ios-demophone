//
//  CallService.swift
//  SwiftPhone
//
//  Created by Diego on 13.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import Foundation
import Combine
import Softphone_Swift

class CallService: NSObject {
    
    enum AttendedTransferType {
        case direct
        case newCall
        case pickCall
    }
    
    var onDismissSelectedCall: PassthroughSubject<Void, Never> = .init()
    var onCallStarted: PassthroughSubject<Void, Never> = .init()
    
    // remove
    var onSingleCallEntriesUpdate: CurrentValueSubject<[Entry], Never> = .init([])
    
    var onConfirmAttendedTransfer: PassthroughSubject<Void, Never> = .init()
    var onCallEntriesUpdate: CurrentValueSubject<[Entry], Never> = .init([])
    var onError: PassthroughSubject<String, Never> = .init()
    var onActiveCallChanged: CurrentValueSubject<Entry?, Never> = .init(nil)
    var onOpenActiveCall: PassthroughSubject<Entry?, Never> = .init()
    
    var singleCallEntries: [Entry] = []
    var attTransferCallEntries: [Entry] = []
    var showConfirmTransferAlert = false
    
    override init() {
        super.init()
    }
    
    deinit {
        CallRedirectionManager.instance().removeStateChangeDelegate(self)
        CallRedirectionManager.instance().removeTargetChangeDelegate(self)
    }
    
    func register() {
        CallRedirectionManager.instance().addStateChangeDelegate(self)
        CallRedirectionManager.instance().addTargetChangeDelegate(self)
    }
    
    func dismissAllCallModals() {
        onDismissSelectedCall.send(())
    }
    
    func refresh() {
        var entries: [Entry] = []
        var singleEntries: [Entry] = []
        
        if let groups = SoftphoneBridge.instance()?.calls()?.conferences()?.list() {
            for groupId in groups {
                entries.append(Entry(groupId: groupId))
                
                if let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: groupId) {
                    for call in calls {
                        singleEntries.append(Entry(call: call));
                    }
                }
            }
        }
        
        onCallEntriesUpdate.send(entries)
        singleCallEntries = singleEntries
        onSingleCallEntriesUpdate.send(singleEntries)
        
        var activeEntry: Entry?
        
        if let groupId = SoftphoneBridge.instance()?.calls()?.conferences()?.getActive(), !groupId.isEmpty {
            activeEntry = Entry(groupId: groupId)
        } else if let calls = SoftphoneBridge.instance()?.calls()?.getActive(), let call = calls.first {
            activeEntry = Entry(call: call)
        } else {
            activeEntry = nil
        }
        
        onActiveCallChanged.send(activeEntry)
    }
    
    func startCall(number: String, dialAction: String) {
        if CallRedirectionManager.instance().currentRedirectFlow.isBlindTransfer() {
            if number.count == 0 {
                return
            }

            if let source =  CallRedirectionManager.instance().redirectSource {
                dismissAllCallModals()
                AppDelegate.theApp().transferCall(call: source, number: number)
                return
            }
        }
        
        if AppDelegate.theApp().call(number: number, dialAction: dialAction) {
            onCallStarted.send(())
        } else {
            onError.send("Could not start the call")
        }
    }
    
    func sendSms(number: String) {
        AppDelegate.theApp().sendExampleSMS(recipient: number)
    }
    
    func sendSmsAttachment(number: String) {
        AppDelegate.theApp().sendExampleSMSWithAttachment(recipient: number)
    }
    
    func hangupCall(_ entry: Entry) {
        onDismissSelectedCall.send(())
        
        if entry.isGroup() {
            AppDelegate.theApp().hangupGroup(groupId: entry.groupId!)
        }
        else {
            AppDelegate.theApp().hangup(call: entry.call!)
        }
    }
    
    func holdCall(_ entry: Entry) {
        if entry.isGroup() {
            AppDelegate.theApp().toggleActiveGroup(groupId: entry.groupId!)
        } else {
            AppDelegate.theApp().toggleHoldForCall(call: entry.call!)
        }
    }
    
    func muteCall() {
        AppDelegate.theApp().toggleMute()
    }
    
    func activateSpeaker() {
        AppDelegate.theApp().toggleSpeaker()
    }
    
    func transfer(entry: Entry) {
        var call: SoftphoneCallEvent
        
        if let entryCall = entry.call {
            call = entryCall
        } else if let entryCall = SoftphoneBridge.instance()?.calls().conferences().getCalls(conference: entry.groupId).first {
            call = entryCall
        } else {
            dismissAllCallModals()
            onError.send("Could not start the transfer")
            return
        }
        
        if CallRedirectionManager.instance().getRedirectCapabilities(call).canBlindTransfer() {
            CallRedirectionManager.instance().setBlindTransferSource(call)
        } else {
            dismissAllCallModals()
            onError.send("Could not start the transfer")
        }
    }
    
    func getCallFromEntry(entry: Entry) -> SoftphoneCallEvent? {
        if let entryCall = entry.call {
            return entryCall
        } else if let entryCall = SoftphoneBridge.instance()?.calls().conferences().getCalls(conference: entry.groupId).first {
            return entryCall
        } else {
            return nil
        }
    }
    
    private func prepareAttendedTransfer(entry: Entry) -> AttendedTransferType? {
        showConfirmTransferAlert = false
        
        guard let call = getCallFromEntry(entry: entry) else {
            return nil
        }
        
        if let capabilities = CallRedirectionManager.instance().getRedirectCapabilities(call) {
            if capabilities.attendedTransferCapability.isDirect() {
                return .direct
            } else if capabilities.attendedTransferCapability.isNewCall() {
                return .newCall
            } else if let _ = capabilities.attendedTransferTargets as? [SoftphoneCallEvent], capabilities.attendedTransferCapability.isPickAnotherCall() {
                showConfirmTransferAlert = true
                return .pickCall
            }
        }
        
        dismissAllCallModals()
        onError.send("Could not start the attended transfer")
        return nil
    }
    
    func startAttendedCall(entry: Entry) -> AttendedTransferType? {
        
        guard let call = getCallFromEntry(entry: entry), let type = prepareAttendedTransfer(entry: entry) else {
            return nil
        }
        
        if let capabilities = CallRedirectionManager.instance().getRedirectCapabilities(call) {
            switch type {
            case .direct:
                showConfirmTransferAlert = false
                CallRedirectionManager.instance().performAttendedTransferBetween(source: call, target: capabilities.attendedTransferTargets.first as? SoftphoneCallEvent)
            case .newCall:
                showConfirmTransferAlert = false
                CallRedirectionManager.instance().setAttendedTransferSource(call)
            case .pickCall:
                showConfirmTransferAlert = true
                CallRedirectionManager.instance().setAttendedTransferSource(call)
                
                if let attendedTransferTargets = capabilities.attendedTransferTargets as? [SoftphoneCallEvent] {
                    var entries: [Entry] = []
                    
                    for target in attendedTransferTargets {
                        entries.append(.init(call: target))
                    }

                    attTransferCallEntries = entries
                    onSingleCallEntriesUpdate.send(entries)
                }
            }
            
            return type
        } else {
            dismissAllCallModals()
            onError.send("Could not start the attended transfer")
            return nil
        }
    }
    
    func startAttendedTransferWithSelectedCall(entry: Entry) {
        CallRedirectionManager.instance().setAttendedTransferTarget(entry.call)
        //CallRedirectionManager.instance().performAttendedTransfer()
    }
    
    func finishAttendedTransfer() {
        CallRedirectionManager.instance().performAttendedTransfer()
    }
    
    func cancelAttendedTransfer() {
        CallRedirectionManager.instance().cancelRedirect()
    }

    func join(_ entry: Entry) {
        guard let call = entry.call, !entry.isGroup() else {
            dismissAllCallModals()
            onError.send("No call was selected")
            return
        }
        
        let otherGroup = groupNotContaining(call: call)
        
        if otherGroup.isEmpty
        {
            dismissAllCallModals()
            onError.send("You need two separate calls to join them together")
            return
        }
        
        dismissAllCallModals()
        AppDelegate.theApp().joinCall(call: call, group: otherGroup)
    }
    
    func split(_ entry: Entry) {
        if entry.isGroup() {
            if SoftphoneBridge.instance().calls().conferences().getSize(entry.groupId) == 1 {
                dismissAllCallModals()
                onError.send("The call is already alone in its group")
            } else {
                dismissAllCallModals()
                AppDelegate.theApp().splitGroup(groupId: entry.groupId!)
            }
        } else {
            guard let groupId = SoftphoneBridge.instance()?.calls()?.conferences()?.get(entry.call) else {
                dismissAllCallModals()
                onError.send("Could not split calls")
                return
            }
            
            if (SoftphoneBridge.instance()?.calls()?.conferences()?.getSize(groupId))! > 0 {
                dismissAllCallModals()
                AppDelegate.theApp().splitCall(call: entry.call!)
            }
            else {
                dismissAllCallModals()
                onError.send("The call is already alone in its group")
            }
        }
    }
    
    func answer(_ entry: Entry) {
        if entry.isGroup() {
            if let call = SoftphoneBridge.instance()?.calls()?.conferences().getCalls(conference: entry.groupId).first {
                let callState = SoftphoneBridge.instance()?.calls()?.getState(call)
                
                if callState == CallState_IncomingRinging || callState == CallState_IncomingIgnored {
                    dismissAllCallModals()
                    AppDelegate.theApp().answerIncomingCall(call: call)
                }
            } else {
                onError.send("The call cannot be answered")
            }
        }
        else {
            let callState = SoftphoneBridge.instance()?.calls()?.getState(entry.call)
            
            if callState == CallState_IncomingRinging || callState == CallState_IncomingIgnored {
                dismissAllCallModals()
                AppDelegate.theApp().answerIncomingCall(call: entry.call!)
            }
        }
    }
    
    func reject(_ entry: Entry) {
        if entry.isGroup() {
            if let call = SoftphoneBridge.instance()?.calls()?.conferences().getCalls(conference: entry.groupId).first {
                let callState = SoftphoneBridge.instance()?.calls()?.getState(call)
                
                if callState == CallState_IncomingRinging || callState == CallState_IncomingIgnored {
                    dismissAllCallModals()
                    AppDelegate.theApp().rejectIncomingCall(call: call)
                }
            } else {
                onError.send("Error while rejecting call")
            }
        }
        else {
            let callState = SoftphoneBridge.instance()?.calls()?.getState(entry.call)
            
            if callState == CallState_IncomingRinging || callState == CallState_IncomingIgnored {
                AppDelegate.theApp().rejectIncomingCall(call: entry.call!)
            }
        }
    }
    
    func openActiveCall() {
        guard let entry = self.onActiveCallChanged.value else {
            return
        }
        
        self.onOpenActiveCall.send(entry)
    }
    
    private func groupNotContaining(call: SoftphoneCallEvent) -> String {
        let groupId = SoftphoneBridge.instance()?.calls()?.conferences()?.get(call)
        if let allGroups = SoftphoneBridge.instance()?.calls()?.conferences()?.list() {
            for otherGroup in allGroups {
                let otherGroupSize = SoftphoneBridge.instance()?.calls()?.conferences()?.getSize(otherGroup)
                
                if otherGroup == groupId || otherGroupSize == 0 {
                    continue
                }
                return otherGroup
            }
        }
        
        return String()
    }
}

extension CallService: CallRedirectionTargetChangeDelegate {
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func redirectTargetChanged(data: TargetChangeData!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let _ = data.newTarget else { return }
        
        if data.type.isAttendedTransfer() && showConfirmTransferAlert {
            onConfirmAttendedTransfer.send(())
        }
    }
}

extension CallService: CallRedirectionStateChangeDelegate {
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func redirectStateChanged(data: StateChangeData!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let isTransferType = data.type.isTransferType()
        var message: String = ""
        
        if data.newState.isSucceeded() {
            message = isTransferType ? "Transfer Complete" : "Forward Complete"
        }
        else if data.newState.isFailed() {
            message = isTransferType ? "Transfer Failed" : "Forward Failed"
        }
        else if data.newState.isCancelled() {
            message = isTransferType ? "Transfer Cancelled" : "Forward Cancelled"
        }
        else if data.newState.isInProgress() {
            message = isTransferType ? "Transfer in Progress" : "Forward in Progress"
        }
    }
}
