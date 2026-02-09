//
//  UserCallView.swift
//  SwiftPhone
//
//  Created by Diego on 10.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct CallDetailView: View {
    
    @StateObject var viewModel: CallDetailViewModel

    private var fixedColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    init(callItem: ActiveCallItem) {
        self._viewModel = StateObject(wrappedValue: CallDetailViewModel(callItem: callItem))
    }
    
    private var airplayView: AirPlayView {
        AirPlayView()
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(alignment: .center, spacing: 16) {
                Text(viewModel.accountName)
                    .fontWeight(.bold)
                    .font(.largeTitle)
                
                Text(viewModel.status)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.green)
                
                if let durationText = viewModel.durationText {
                    Text(durationText)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.secondary)
                        .opacity(viewModel.isOnHold ? 0 : 1)
                }
            }
            .padding(.vertical, 64)
            .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()
            
            buttonGrid
            
            buttonRow
            
            if viewModel.speakerSelected {
                airplayView
                    .frame(width: 0, height: 0)
            } 
        }
        .onChange(of: viewModel.speakerSelected, perform: { newValue in
            if newValue {
                airplayView.showAirPlayMenu()
            }
        })
        .padding(.horizontal)
        .background(Color(uiColor: .systemGroupedBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $viewModel.selectCallPicker) { type in
            switch type {
            case .join, .attendedTransferPick:
                CallSelectionView(entries: viewModel.getEntriesForSelection(type: type),
                                  onTap: { entry in
                    viewModel.onCallSelection(entry: entry, type: type)
                })
            case .transfer, .attendedTransferNew:
                CallTransferInputView(transferNumber: $viewModel.transferNumber,
                                      onTransfer: {
                    viewModel.onCallInput(type: type)
                },
                                      onCancel: {
                    viewModel.dismissInput()
                })
            }
        }
        .alert("Do you want to complete the transfer?", isPresented: $viewModel.confirmAlert) {
            Button("Yes") {
                viewModel.confirmAttendedTransfer()
            }
            
            Button("No") {
                viewModel.cancelAttendedTransfer()
            }
        }
    }

    var buttonGrid: some View {
        LazyVGrid(columns: fixedColumns, spacing: 16) {
            ForEach(viewModel.gridButtons, id: \.self) { button in
                switch button {
                case .speaker:
                    UserCallGridActionButton(isOn: $viewModel.isSpeakerOn,
                                             button: button) {
                        viewModel.toggleSpeaker()
                    }
                default:
                    UserCallGridActionButton(isOn: .constant(false),
                                             button: button) {
                        switch button {
                        case .transfer:
                            viewModel.showTransferCall()
                        case .attendedTransfer:
                            viewModel.showAttendedTransferCall()
                        case .join:
                            viewModel.showJoin()
                        case .split:
                            viewModel.split()
                        default:
                            break
                        }
                    }
                }
            }
        }
        .padding(.vertical)
    }
    
    var buttonRow: some View {
        HStack {
            ForEach(viewModel.lowerButtons) { button in
                switch button {
                case .hold:
                    UserCallActionButton(isOn: $viewModel.isOnHold,
                                         button: button) {
                        viewModel.holdCall()
                    }
                case .mute:
                    UserCallActionButton(isOn: $viewModel.isMuteOn,
                                         button: button) {
                        viewModel.muteCall()
                    }
                case .answer:
                    UserCallActionButton(isOn: .constant(false),
                                         button: button) {
                        viewModel.answer()
                    }
                case .reject:
                    UserCallActionButton(isOn: .constant(false),
                                         button: button) {
                        viewModel.reject()
                    }
                default:
                    UserCallActionButton(isOn: .constant(false),
                                         button: button) {
                        switch button {
                        case .hangup:
                            viewModel.hangupCall()
                        default:
                            break
                        }
                    }
                }
            }
         }
    }
}


#Preview {
    VStack {
        CallDetailView(callItem: .init(account: "Acc", status: "Status", incoming: true, canBeAnswered: false, duration: nil, isOnHold: false, entry: Entry(groupId: "123")))
            .padding(.bottom, 32)
    }
}
