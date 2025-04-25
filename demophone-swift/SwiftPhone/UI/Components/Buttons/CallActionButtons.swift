//
//  CallActionButtons.swift
//  SwiftPhone
//
//  Created by Diego on 14.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct UserCallGridActionButton: View {
    @Binding var isOn: Bool
    var button: ActionButton
    var action: () -> Void
    
    var body: some View {
        Button {
            isOn.toggle()
            action()
        } label: {
            Text(button.title)
                .font(.subheadline)
                .fontWeight(.bold)
                .frame(height: 80)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .gray : .accentColor)
    }
}

struct UserCallActionButton: View {
    @Binding var isOn: Bool
    var button: ActionButton
    var action: () -> Void
    
    var body: some View {
        Button {
            isOn.toggle()
            action()
        } label: {
            Image(systemName: button.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 25, height: 25)
                .padding(8)
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .gray : tintForButton(for: button))
    }
    
    func tintForButton(for button: ActionButton) -> Color {
        if button.isDestroyStyle {
            return Color.red
        } else if button.isAcceptStyle {
            return Color.green
        } else {
            return Color.accentColor
        }
    }
}
