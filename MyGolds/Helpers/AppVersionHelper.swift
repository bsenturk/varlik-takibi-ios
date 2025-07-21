//
//  AppVersionHelper.swift
//  MyGolds
//
//  Created by Burak Şentürk on 20.07.2025.
//

import Foundation

struct AppVersionHelper {
    static var appVersion: String {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "Bilinmiyor"
        }
        return version
    }
    
    static var buildNumber: String {
        guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return "Bilinmiyor"
        }
        return build
    }
    
    static var fullVersionString: String {
        return "Sürüm \(appVersion) (\(buildNumber))"
    }
    
    static var displayVersionString: String {
        return "Sürüm \(appVersion)"
    }
    
    static var appName: String {
        guard let name = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
                         Bundle.main.infoDictionary?["CFBundleName"] as? String else {
            return "Varlık Takibi"
        }
        return name
    }
}
