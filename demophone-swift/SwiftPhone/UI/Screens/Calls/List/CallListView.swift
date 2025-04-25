//
//  UserCallListView.swift
//  SwiftPhone
//
//  Created by Diego on 12.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

private struct CallListItemView: View {
    
    var title: String
    var status: String
    var isOnHold: Bool
    var duration: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let duration = duration {
                    Text(duration)
                        .font(.footnote)
                        .foregroundStyle(Color.gray)
                }
            }
            
            Text(isOnHold ? "\(status) (On Hold)" : status)
                .font(.footnote)
                .fontWeight(.medium)
        }
        .contentShape(Rectangle())
    }
}

struct CallListView: View {
    
    @StateObject var viewModel = CallListViewModel()
    
    var body: some View {
        NavigationView {
            if viewModel.callList.isEmpty {
                VStack {
                    Spacer()
                    
                    Text("There are no outgoing or incoming calls")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .navigationTitle("Active Calls")
            } else {
                List {
                    if (!viewModel.outgoingCalls.isEmpty) {
                        Section("Outgoing") {
                            ForEach(viewModel.outgoingCalls) { call in
                                CallListItemView(title: call.account,
                                                 status: call.status,
                                                 isOnHold: call.isOnHold,
                                                 duration: call.duration)
                                    .onTapGesture { viewModel.selectedCall = call }
                            }
                        }
                    }
                    
                    if (!viewModel.incomingCalls.isEmpty) {
                        Section("Incoming") {
                            ForEach(viewModel.incomingCalls) { call in
                                CallListItemView(title: call.account,
                                                 status: call.status,
                                                 isOnHold: call.isOnHold,
                                                 duration: call.duration)
                                    .onTapGesture { viewModel.selectedCall = call }
                            }
                        }
                    }
                }
                .sheet(item: $viewModel.selectedCall, content: { call in
                    CallDetailView(callItem: call)
                })
                .navigationTitle("Active Calls")
            }
        }
    }
}

#Preview {
    CallListView()
}
