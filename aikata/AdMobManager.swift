import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

final class AdMobManager: NSObject {
    static let shared = AdMobManager()

    private var didStartMobileAds = false
    private var didRequestTracking = false
    private var didRequestUmp = false

    func configureOnLaunch() {
#if canImport(GoogleMobileAds)
        MobileAds.shared.requestConfiguration.tagForUnderAgeOfConsent = false
#endif
    }

    func requestConsentAndStartAdsIfNeeded() {
        if didStartMobileAds { return }

#if canImport(UserMessagingPlatform)
        if !didRequestUmp {
            didRequestUmp = true
            let parameters = RequestParameters()
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] _ in
                guard let self else { return }
#if canImport(UIKit)
                guard let viewController = UIApplication.shared.topMostViewController() else {
                    self.requestTrackingIfNeeded()
                    self.startMobileAdsIfNeeded()
                    return
                }
                ConsentForm.loadAndPresentIfRequired(from: viewController) { [weak self] _ in
                    self?.requestTrackingIfNeeded()
                    self?.startMobileAdsIfNeeded()
                }
#else
                self.requestTrackingIfNeeded()
                self.startMobileAdsIfNeeded()
#endif
            }
            return
        }
#endif

        requestTrackingIfNeeded()
        startMobileAdsIfNeeded()
    }

    private func requestTrackingIfNeeded() {
#if canImport(AppTrackingTransparency)
        if didRequestTracking { return }
        didRequestTracking = true
        if #available(iOS 14, *) {
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
        }
#endif
    }

    private func startMobileAdsIfNeeded() {
#if canImport(GoogleMobileAds)
        if didStartMobileAds { return }
        didStartMobileAds = true
        MobileAds.shared.start()
#endif
    }
}

#if canImport(UIKit)
private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        let root = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
