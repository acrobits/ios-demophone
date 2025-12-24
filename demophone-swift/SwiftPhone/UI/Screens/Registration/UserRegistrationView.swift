//
//  UserRegistrationView.swift
//  SwiftPhone
//
//  Created by Diego on 10.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct UserRegistrationView: View {
    
    enum Field {
        case number
    }
    
    @StateObject var viewModel = UserRegistrationViewModel()
    @FocusState private var focusedField: Field?
    
    var body: some View {
        NavigationView {
            Form {
                Section("User Account") {
                    LabelFormItem(title: "Username", detail: viewModel.userAccount)
                    
                    if viewModel.hideRegistered {
                        SwitchFormItem(title: "Register user", isOn: $viewModel.registeredAccount)
                    }
                    
                    LabelFormItem(title: "State", detail: viewModel.state)
                }
                
                if viewModel.registeredAccount {
                    Section("Call and Message") {
                        TextField("Enter number to call or message", text: $viewModel.numberForCall)
                            .keyboardType(.phonePad)
                            .focused($focusedField, equals: .number)
                        
                        Button {
                            viewModel.startCall(dialAction: "voiceCall")
                            focusedField = nil
                        } label: {
                            Text("Make a Call")
                                .fontWeight(.bold)
                        }
                        .tint(viewModel.numberForCall.isEmpty ? Color.gray : Color.green)
                        .disabled(viewModel.numberForCall.isEmpty)
                        
#if VIDEO_FEATURE
                        Button {
                            viewModel.startCall(dialAction: "videoCall")
                            focusedField = nil
                        } label: {
                            Text("Make a Video Call")
                                .fontWeight(.bold)
                        }
                        .tint(viewModel.numberForCall.isEmpty ? Color.gray : Color.green)
                        .disabled(viewModel.numberForCall.isEmpty)
#endif
                        
                        Button {
                            viewModel.sendSms()
                            focusedField = nil
                        } label: {
                            Text("Send a SMS")
                                .fontWeight(.medium)
                        }
                        .tint(viewModel.numberForCall.isEmpty ? Color.gray : Color.teal)
                        .disabled(viewModel.numberForCall.isEmpty)
                        
                        Button {
                            viewModel.sendSmsAttachment()
                            focusedField = nil
                        } label: {
                            Text("Send a SMS with attachment")
                                .fontWeight(.medium)
                        }
                        .tint(viewModel.numberForCall.isEmpty ? Color.gray : Color.cyan)
                        .disabled(viewModel.numberForCall.isEmpty)
                    }
                }
                
                Section("") {
                    Button {
                        viewModel.dumpLog()
                    } label: {
                        Text("Dump Log")
                            .fontWeight(.medium)
                            .foregroundStyle(Color(uiColor: .label))
                    }
                    
                    Button {
                        viewModel.toogleSDK()
                    } label: {
                        Text(viewModel.isSDKActive ? "Stop SDK" : "Start SDK")
                            .fontWeight(.medium)
                            .foregroundStyle(viewModel.isSDKActive ? Color.red : Color.accentColor)
                    }
                    .disabled(!viewModel.isSDKButtonEnabled)
                    .opacity(viewModel.isSDKButtonEnabled ? 1 : 0.7)
                }
            }
            .navigationTitle("Demophone")
        }
    }
}

#Preview {
    UserRegistrationView()
}
