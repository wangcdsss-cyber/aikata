//
//  ContentView.swift
//  aikata
//
//  Created by SHIHOU on 2026/05/06.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var themeStore = ThemeStore()

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView()
            } else if authManager.currentUser != nil {
                MainHomeView()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(authManager)
        .environmentObject(themeStore)
        .preferredColorScheme(themeStore.preferredColorScheme)
        .tint(themeStore.selectedTheme.primary)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
