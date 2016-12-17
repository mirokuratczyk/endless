/*
 * Copyright (c) 2016, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

import Foundation
import SystemConfiguration

class PsiphonCommon {
    struct ConnectionStatus {
        var isConnected: Bool
        var onWifi: Bool
    }
    
    static func getNetworkType() -> String {
        let connectionStatus = self.getConnectionStatus()
        
        switch (connectionStatus.isConnected, connectionStatus.onWifi) {
        case (false, _):
            return ""
        case (true, false):
            return "MOBILE"
        case (true, true):
            return "WIFI"
        }
    }
    
    // Determine device's network connection status
    // http://stackoverflow.com/questions/25623272/how-to-use-scnetworkreachability-in-swift
    static func getConnectionStatus() -> ConnectionStatus {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            return ConnectionStatus(isConnected: false, onWifi: false)
        }
        
        var flags : SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return ConnectionStatus(isConnected: false, onWifi: false)
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let onWifi = !flags.contains(.isWWAN)
        
        return ConnectionStatus(isConnected: isReachable && !needsConnection, onWifi: onWifi)
    }
    
    static func getRandomBytes(numBytes: Int) -> [UInt8]? {
        let bytesCount = numBytes
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        
        // Generate random bytes
        let result = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        if (result != 0) {
            return Optional.none
        }
        
        return Optional.some(randomBytes)
    }
}

// ISO8601DateFormatter method only available in iOS 10.0+
// Follows format specified in `getISO8601String` https://bitbucket.org/psiphon/psiphon-circumvention-system/src/default/Android/app/src/main/java/com/psiphon3/psiphonlibrary/Utils.java#Utils.java-614
// http://stackoverflow.com/questions/28016578/swift-how-to-create-a-date-time-stamp-and-format-as-iso-8601-rfc-3339-utc-tim
extension Date {
    struct Formatter {
        static let iso8601: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX") // https://developer.apple.com/library/mac/qa/qa1480/_index.html
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSX"
            return formatter
        }()
    }
    var iso8601: String {
        return Formatter.iso8601.string(from: self)
    }
}

extension String {
    var dateFromISO8601: Date? {
        return Date.Formatter.iso8601.date(from: self)
    }
}
