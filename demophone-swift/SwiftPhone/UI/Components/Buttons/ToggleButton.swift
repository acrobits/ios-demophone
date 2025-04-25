//
//  CallButton.swift
//  SwiftPhone
//
//  Created by Diego on 13.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct ColoredToggleButton<Content: View>: View {
    @State var isSelected: Bool = false
    
    var selectedBackground: Color?
    var background: Color?
    
    var content: () -> Content
    var action: () -> Void
    
    var body: some View {
        ToggleButton(isSelected: isSelected,
                         selectedBackground: selectedBackground,
                         background: background,
                         content: content,
                         action: action)
    }
}

struct ToggleButton<Content: View, BackgroundType: View>: View {
    @State var isSelected: Bool = false
    
    var selectedBackground: BackgroundType?
    var background: BackgroundType?
    
    var content: () -> Content
    var action: () -> Void
    
    var body: some View {
        Button {
            isSelected.toggle()
            action()
        } label: {
            content()
        }
        .background(content: {
            isSelected ? selectedBackground : background
        })
        .animation(.easeInOut, value: isSelected)
    }
}

#Preview {
    VStack {
        ToggleButton(background: Color.green) {
            Image(systemName: "phone.fill")
                .padding()
        } action: {
            
        }
        .clipShape(Circle())
        
        ToggleButton(isSelected: true, selectedBackground: Color.yellow, background: Color.green) {
            Text("Hello")
                .padding()
        } action: {
            
        }
        .clipShape(Circle())
    }

}
