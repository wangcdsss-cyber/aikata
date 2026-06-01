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

    var body: some View {
#if canImport(GoogleMobileAds)
        VStack(spacing: 0) {
            if containerWidth > 0, !hasFailedToLoad {
                AdMobBannerRepresentable(
                    adUnitId: adUnitId,
                    width: containerWidth,
                    hasFailedToLoad: $hasFailedToLoad
                )
                .frame(height: bannerHeight(for: containerWidth))
                .padding(.vertical, verticalPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .onAppear {
            if containerWidth <= 0 {
                containerWidth = UIScreen.main.bounds.width
            }
            if hasFailedToLoad {
                hasFailedToLoad = false
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

    func makeCoordinator() -> Coordinator {
        Coordinator(hasFailedToLoad: $hasFailedToLoad)
    }

    func makeUIView(context: Context) -> BannerView {
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitId
        bannerView.delegate = context.coordinator
        if let controller = UIApplication.shared.topMostViewController() {
            bannerView.rootViewController = controller
        }
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        if uiView.adSize.size.width != adSize.size.width || uiView.adSize.size.height != adSize.size.height {
            uiView.adSize = adSize
        }
        if uiView.rootViewController == nil, let controller = UIApplication.shared.topMostViewController() {
            uiView.rootViewController = controller
            uiView.load(Request())
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var hasFailedToLoad: Bool

        init(hasFailedToLoad: Binding<Bool>) {
            _hasFailedToLoad = hasFailedToLoad
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            hasFailedToLoad = true
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
