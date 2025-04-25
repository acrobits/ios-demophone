//
//  SwitchFormItem.swift
//  SwiftPhone
//
//  Created by Diego on 10.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct SwitchFormItem: View {
    
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text("Registered")
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
    }
}

#Preview {
    VStack {
        SwitchFormItem(title: "Name", isOn: .constant(true))
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
        
        SwitchFormItem(title: "Name", isOn: .constant(false))
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
    }
}
