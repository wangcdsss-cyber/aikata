//
//  ContentView.swift
//  aikata
//
//  Created by SHIHOU on 2026/05/06.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView()
            } else if authManager.currentUser != nil {
                PostListView()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(authManager)
    }
}

#Preview {
    ContentView()
}
