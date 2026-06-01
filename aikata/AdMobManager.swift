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
        GADMobileAds.sharedInstance().requestConfiguration.tagForUnderAgeOfConsent = false
#endif
    }

    func requestConsentAndStartAdsIfNeeded() {
        if didStartMobileAds { return }

#if canImport(UserMessagingPlatform)
        if !didRequestUmp {
            didRequestUmp = true
            let parameters = UMPRequestParameters()
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { [weak self] _ in
                guard let self else { return }
                guard let viewController = UIApplication.shared.topMostViewController() else {
                    self.startMobileAdsIfNeeded()
                    return
                }
                UMPConsentForm.loadAndPresentIfRequired(from: viewController) { [weak self] _ in
                    self?.requestTrackingIfNeeded()
                    self?.startMobileAdsIfNeeded()
                }
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
        GADMobileAds.sharedInstance().start(completionHandler: nil)
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
