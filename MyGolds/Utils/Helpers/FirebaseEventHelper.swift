//
//  FirebaseEventHelper.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 16.03.2024.
//

import FirebaseAnalytics

final class FirebaseEventHelper {
    
    enum EventName: String {
        case adShownFail = "ad_shown_fail"
        case adWillPresent = "ad_will_present"
        case adWillDismiss = "ad_will_dismiss"
        case adDidDismiss = "ad_did_dismiss"
        case adDidClick = "ad_did_click"
        case trackingAuthorized = "tracking_authorized"
        case trackingNonAuthorized = "tracking_nonAuthorized"
        case adNotReady = "ad_not_ready"
        case adFailedToLoad = "ad_failed_to_load"
    }
    
    
    static func sendEvent(event: EventName, parameters: [String: Any]?) {
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }
}
