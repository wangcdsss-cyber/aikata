import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

#if canImport(UIKit)
import UIKit
#endif

struct AdMobBannerView: View {
    let adUnitId: String
    let verticalPadding: CGFloat

    @State private var hasFailedToLoad = false
    @State private var containerWidth: CGFloat = 0
    @State private var retryCount = 0
    @State private var lastErrorText: String? = nil

    var body: some View {
#if canImport(GoogleMobileAds)
        VStack(spacing: 0) {
            if containerWidth > 0 {
                if hasFailedToLoad {
                    Color.clear
                        .frame(height: 0)
                } else {
                    AdMobBannerRepresentable(
                        adUnitId: adUnitId,
                        width: containerWidth,
                        hasFailedToLoad: $hasFailedToLoad,
                        lastErrorText: $lastErrorText
                    )
                    .frame(height: bannerHeight(for: containerWidth))
                    .padding(.vertical, verticalPadding)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .onAppear {
            if containerWidth <= 0 {
                containerWidth = UIScreen.main.bounds.width
            }
        }
        .onChange(of: hasFailedToLoad) { _, newValue in
            if newValue, retryCount < 1 {
                retryCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    hasFailedToLoad = false
                }
            }
        }
#else
        EmptyView()
#endif
    }

#if canImport(GoogleMobileAds)
    private func bannerHeight(for width: CGFloat) -> CGFloat {
        let size = currentOrientationAnchoredAdaptiveBanner(width: width)
        return size.size.height
    }
#endif
}

#if canImport(GoogleMobileAds)
private struct AdMobBannerRepresentable: UIViewRepresentable {
    let adUnitId: String
    let width: CGFloat
    @Binding var hasFailedToLoad: Bool
    @Binding var lastErrorText: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            hasFailedToLoad: $hasFailedToLoad,
            lastErrorText: $lastErrorText
        )
    }

    func makeUIView(context: Context) -> BannerView {
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitId
        bannerView.delegate = context.coordinator
        if let controller = UIApplication.shared.topMostViewController() {
            bannerView.rootViewController = controller
        }
        context.coordinator.didStartLoading()
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        if uiView.adSize.size.width != adSize.size.width || uiView.adSize.size.height != adSize.size.height {
            uiView.adSize = adSize
        }
        if uiView.adUnitID != adUnitId {
            uiView.adUnitID = adUnitId
        }
        if uiView.rootViewController == nil, let controller = UIApplication.shared.topMostViewController() {
            uiView.rootViewController = controller
            context.coordinator.didStartLoading()
            uiView.load(Request())
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var hasFailedToLoad: Bool
        @Binding var lastErrorText: String?

        private var didReceiveCallback = false
        private var timeoutWorkItem: DispatchWorkItem?

        init(hasFailedToLoad: Binding<Bool>, lastErrorText: Binding<String?>) {
            _hasFailedToLoad = hasFailedToLoad
            _lastErrorText = lastErrorText
        }

        func didStartLoading() {
            DispatchQueue.main.async {
                self.hasFailedToLoad = false
            }

            didReceiveCallback = false
            timeoutWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.didReceiveCallback { return }
                DispatchQueue.main.async {
                    self.lastErrorText = "Timeout (no callback): 12s"
                    self.hasFailedToLoad = true
                }
            }
            timeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: workItem)
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            didReceiveCallback = true
            timeoutWorkItem?.cancel()
            DispatchQueue.main.async {
                self.hasFailedToLoad = false
                self.lastErrorText = nil
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            let nsError = error as NSError
            didReceiveCallback = true
            timeoutWorkItem?.cancel()
            DispatchQueue.main.async {
                self.lastErrorText = "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
                self.hasFailedToLoad = true
            }
        }
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
#endif
