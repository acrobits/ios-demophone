//
//  ActiveCallHeader.swift
//  SwiftPhone
//
//  Created by Diego on 10.03.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct ActiveCallHeader: View {
    
    let onAction: () -> Void
    
    var body: some View {
        HStack {
            Text("Go to active call")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.white)
            
            Image(systemName: "arrow.right.square.fill")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(Color.white)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color.green)
        .onTapGesture {
            onAction()
        }
    }
}

#Preview {
    ActiveCallHeader { }
}
