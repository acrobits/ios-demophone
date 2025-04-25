//
//  CircleButton.swift
//  SwiftPhone
//
//  Created by Diego on 13.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct ToggleColor {
    var onColor: Color = .clear
    var offColor: Color = .clear
}

struct ToggleBackgroundColorKey: EnvironmentKey {
    static var defaultValue: ToggleColor = ToggleColor()
}

struct ToggleTintColorKey: EnvironmentKey {
    static var defaultValue: ToggleColor = ToggleColor()
}

extension EnvironmentValues {
    var toggleBackgroundColor: ToggleColor {
        get { self[ToggleBackgroundColorKey.self] }
        set { self[ToggleBackgroundColorKey.self] = newValue }
    }
    
    var toggleTintColor: ToggleColor {
        get { self[ToggleTintColorKey.self] }
        set { self[ToggleTintColorKey.self] = newValue }
    }
}

struct CircleButton<Content: View>: View {
    
    var label: () -> Content
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            label()
        }
        .clipShape(Circle())
    }
}

struct ToggleCircleButton<Content: View>: View {
    @Environment(\.toggleBackgroundColor) var backgroundColor
    @Environment(\.toggleTintColor) var tintColor
    @State var isSelected = false
    
    var label: () -> Content
    var action: () -> Void
    
    var body: some View {
        Button {
            isSelected.toggle()
            action()
        } label: {
            label()
                .tint(isSelected ? tintColor.onColor : tintColor.offColor)
        }
        .background(isSelected ? backgroundColor.onColor : backgroundColor.offColor)
        .clipShape(Circle())
    }
}

extension View {
    func setToggleBackgroundColor(_ toggleColor: ToggleColor) -> some View {
        environment(\.toggleBackgroundColor, toggleColor)
    }
    
    func setToggleTintColor(_ toggleColor: ToggleColor) -> some View {
        environment(\.toggleTintColor, toggleColor)
    }
}

#Preview {
    CircleButton {
        Image(systemName: "phone.fill")
            .padding()
    } action: {
        
    }
    
    ToggleCircleButton {
        Image(systemName: "phone.fill")
            .padding()
    } action: {
        
    }
    .setToggleTintColor(ToggleColor(onColor: .blue, offColor: .red))
    .setToggleBackgroundColor(ToggleColor(onColor: .green, offColor: .brown))
}
