//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 29.11.2021.
//

import Foundation

public enum Configuration : String {
    enum Error: Swift.Error {
        case missingKey, invalidValue
    }
    case source = "SOURCE"
    case apiId = "API_ID"
    case apiHash = "API_HASH"
    case bundleId = "BUNDLE_ID"
    case teamId = "TEAM_ID"
    
    public static func value(for key: Configuration) -> String? {
        guard let value = Bundle.main.infoDictionary?[key.rawValue] as? String else {
            return nil
        }
        return value
    }

    public static func credential(_ key: Configuration) -> String? {
        guard let value = Bundle.main.infoDictionary?[key.rawValue] as? String else {
            return nil
        }
        if value.isEmpty || value.hasPrefix("${") {
            return nil
        }
        return value
    }
}
