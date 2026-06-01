//
//  aikataApp.swift
//  aikata
//
//  Created by SHIHOU on 2026/05/06.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
#if canImport(FirebaseCore)
        FirebaseApp.configure()
#endif
        AppAppearance.configure()
        AdMobManager.shared.configureOnLaunch()
        AdMobManager.shared.requestConsentAndStartAdsIfNeeded()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AdMobManager.shared.requestConsentAndStartAdsIfNeeded()
    }
}

@main
struct aikataApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
