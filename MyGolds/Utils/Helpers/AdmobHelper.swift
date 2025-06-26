//
//  AdmobHelper.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 16.03.2024.
//

import GoogleMobileAds

class AdCoordinator: NSObject {
    private var ad: GADInterstitialAd?
    
    private var adUnitId: String {
        #if DEBUG
        return "/6499/example/interstitial"
        #else
        return "ca-app-pub-2545255000258244/8586611964"
        #endif
    }
    
    func loadAd() {
        let request = GADRequest()
        request.scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        GADInterstitialAd.load(
            withAdUnitID: adUnitId, request: request
        ) { ad, error in
            if let error {
                FirebaseEventHelper.sendEvent(event: .adFailedToLoad, parameters: ["reason": error.localizedDescription])
                #if DEBUG
                print("Failed to load ad with error: \(error.localizedDescription)")
                #endif
                return
            }
            
            self.ad = ad
            self.ad?.fullScreenContentDelegate = self
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                presentAd()
            }
        }
    }
    
    func presentAd() {
        guard let fullScreenAd = ad else {
            FirebaseEventHelper.sendEvent(event: .adNotReady, parameters: nil)
            #if DEBUG
            print("Ad wasn't ready")
            #endif
            return
        }
        
        fullScreenAd.present(fromRootViewController: nil)
    }
}

// MARK: - GADFullScreenContentDelegate methods
extension AdCoordinator: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        FirebaseEventHelper.sendEvent(event: .adShownFail, parameters: nil)
    }
    
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        FirebaseEventHelper.sendEvent(event: .adWillPresent, parameters: nil)
    }
    
    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        FirebaseEventHelper.sendEvent(event: .adDidClick, parameters: nil)
    }
    
    
    func adWillDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        FirebaseEventHelper.sendEvent(event: .adWillDismiss, parameters: nil)
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        FirebaseEventHelper.sendEvent(event: .adDidDismiss, parameters: nil)
    }
}
