//
//  HomeView.swift
//  SwiftPhone
//
//  Created by Diego on 13.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI

struct HomeView: View {
    
    @StateObject var viewModel = HomeViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            
            if (viewModel.activeCallExists)
            {
                ActiveCallHeader {
                    viewModel.openActiveCall()
                }
            }
            
            TabView(selection: $viewModel.selectedTab) {
                UserRegistrationView()
                    .tabItem {
                        Label("Registration", systemImage: "person")
                    }
                    .tag(1)
                
                CallListView()
                    .tabItem {
                        Label("Calls", systemImage: "phone.fill")
                    }
                    .tag(2)
            }
        }
        .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
            Button("OK") {
                viewModel.showAlert = false
            }
        }
    }
}

#Preview {
    HomeView()
}
