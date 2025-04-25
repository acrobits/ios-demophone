//
//  CallInputView.swift
//  SwiftPhone
//
//  Created by Diego on 16.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct CallTransferInputView: View {
    @Binding var transferNumber: String
    var onTransfer: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Enter the number for transfer", text: $transferNumber)
                        .padding(.vertical)
                    
                    HStack(spacing: 16) {
                        Button {
                            onTransfer()
                        } label: {
                            Text("Transfer")
                                .padding(8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        
                        Button {
                            onCancel()
                        } label: {
                            Text("Cancel")
                                .padding(8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.red)
                    }
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Transfer Call")
        }
    }
}

#Preview {
    VStack {

    }
    .sheet(isPresented: .constant(true)) {
        CallTransferInputView(transferNumber: .constant(""), onTransfer: {}, onCancel: {})
    }
}
