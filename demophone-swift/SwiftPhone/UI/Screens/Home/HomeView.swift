//
//  HomeView.swift
//  SwiftPhone
//
//  Created by Diego on 13.01.2025.
//  Copyright © 2025 Acrobits. All rights reserved.
//

import SwiftUI
import Softphone_Swift

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
                
#if VIDEO_FEATURE
                VideoScreenView()
                    .tabItem {
                        Label("Video", systemImage: "video.fill")
                    }
                    .tag(3)
#endif
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
