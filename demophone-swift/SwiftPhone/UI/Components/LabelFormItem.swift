//
//  LabelFormItem.swift
//  SwiftPhone
//
//  Created by Diego on 10.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct LabelFormItem: View {
    
    let title: String
    let detail: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
    }
}

#Preview {
    LabelFormItem(title: "My Title", detail: "My Detail")
        .padding()
        .background(Color(uiColor: UIColor.secondarySystemBackground))
}
