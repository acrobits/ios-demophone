//
//  CallTransferView.swift
//  SwiftPhone
//
//  Created by Diego on 15.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct CallSelectionView: View {
    
    private struct EntryWrapper: Identifiable {
        let id = UUID()
        let entry: Entry
        
        var title: String {
            entry.call?.getRemoteUser(index: 0)?.displayName ?? "Call"
        }
    }
    
    private let entries: [EntryWrapper]
    private let onTap: (Entry) -> Void
    
    init(entries: [Entry], onTap: @escaping (Entry) -> Void) {
        self.entries = entries.map {
            EntryWrapper(entry: $0)
        }
        self.onTap = onTap
    }
    
    var body: some View {
        NavigationView {
            if (self.entries.isEmpty) {
                Text("No calls are available for selection")
                    .font(.body)
                    .fontWeight(.semibold)
            } else {
                List {
                    ForEach(entries) { call in
                        Text(call.title)
                            .fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTap(call.entry)
                            }
                    }
                }
                .navigationTitle("Select a call")
            }
        }
    }
}

#Preview {
    CallSelectionView(entries: []) { entry in
        
    }
}
