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
import UIKit
import WebKit
import Security

struct FeedbackFormConstants {
    static let thumbIndexUnselected = -1
    static let questionHash = "24f5c290039e5b0a2fd17bfcdb8d3108"
    static let questionTitle = "Overall satisfaction"
}

func jsonToDictionary(string: String) -> [String: AnyObject]? {
    if let data = string.data(using: .utf8) {
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject]
        } catch {
            print(error.localizedDescription)
        }
    }
    return nil
}

@objc class FeedbackUpload : NSObject {
    class func valOrNull(opt: AnyObject?) -> AnyObject {
        if let val = opt {
            return val
        } else {
            return NSNull()
        }
    }
    
    struct Feedback {
        var title: String
        var question: String
        var answer: Int
        
        var description : String {
            return "[{\"answer\":\(answer),\"question\":\"\(question)\", \"title\":\"\(title)\"}]"
        }
    }
    
    // Form and send feedback blob which conforms to structure
    // expected by the feedback template for ios,
    // https://bitbucket.org/psiphon/psiphon-circumvention-system/src/default/EmailResponder/FeedbackDecryptor/templates/?at=default
    // Matching format used by android client,
    // https://bitbucket.org/psiphon/psiphon-circumvention-system/src/default/Android/app/src/main/java/com/psiphon3/psiphonlibrary/Diagnostics.java
    class func generateAndSendFeedback(thumbIndex: Int, comments: String, email: String, sendDiagnosticInfo: Bool, psiphonConfig: String) {
        do {
            var config: [String: AnyObject] = [:]
            
            // Serialize psiphon config file
            if let dict = jsonToDictionary(string: psiphonConfig) {
                config = dict
            } else {
                throw PsiphonError.Runtime(NSLocalizedString("Failed to serialize psiphon_config", comment: "Error message generated when serializing psiphon_config to dictionary fails"))
            }

            var feedbackBlob: [String:AnyObject] = [:]

            // Ensure valid survey response
            if (thumbIndex < -1 || thumbIndex > 1) {
                throw PsiphonError.Runtime(NSLocalizedString("Invalid feedback input", comment: "Error message generated when invalid feedback form input is received"))
            }

            // Ensure either feedback or survey response was completed
            if (thumbIndex == -1 && sendDiagnosticInfo == false && comments.characters.count == 0 && email.characters.count == 0) {
                throw PsiphonError.Runtime(NSLocalizedString("User submitted empty feedback", comment: "Error message generated when user attempts to submit an empty feedback form"))
            }

            // Check survey response
            var surveyResponse = ""
            if (thumbIndex != FeedbackFormConstants.thumbIndexUnselected) {
                surveyResponse = Feedback(title: FeedbackFormConstants.questionTitle, question: FeedbackFormConstants.questionHash, answer: thumbIndex).description
            }
            
            feedbackBlob["Feedback"] = [
                "email": email,
                "Message": [
                    "text": comments
                ],
                "Survey": [
                    "json": surveyResponse
                ]
                ] as AnyObject
            
            // If user decides to disclose diagnostics data
            if (sendDiagnosticInfo == true) {
                
                var diagnosticHistoryArray: [[String:AnyObject]] = []
                
                for diagnosticEntry in PsiphonData.sharedInstance.getDiagnosticHistory() {
                    let entry: [String:AnyObject] = [
                        "data": diagnosticEntry.getData() as AnyObject,
                        "msg": diagnosticEntry.getMsg() as AnyObject,
                        "timestamp!!timestamp": diagnosticEntry.getTimestamp() as AnyObject
                    ]
                    diagnosticHistoryArray.append(entry)
                }
                
                var statusHistoryArray: [[String:AnyObject]] = []
                
                for statusEntry in PsiphonData.sharedInstance.getStatusHistory() { // Sensitive logs pre-removed
                    let entry: [String:AnyObject] = [
                        "id": statusEntry.getId() as AnyObject,
                        "timestamp!!timestamp": statusEntry.getTimestamp() as AnyObject,
                        "priority": statusEntry.getPriority() as AnyObject,
                        "formatArgs": valOrNull(opt: statusEntry.getFormatArgs() as AnyObject?), // Sensitive format args pre-removed
                        "throwable": valOrNull(opt: statusEntry.getThrowable() as AnyObject?)
                    ]
                    statusHistoryArray.append(entry)
                }
                
                let diagnosticInfo = [
                    "DiagnosticHistory": diagnosticHistoryArray,
                    "StatusHistory": statusHistoryArray,
                    "SystemInformation": [
                        "Build": gatherDeviceInfo(),
                        "PsiphonInfo": [
                            "CLIENT_VERSION": Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String,
                            "PROPAGATION_CHANNEL_ID": config["PropagationChannelId"] as! String,
                            "SPONSOR_ID": config["SponsorId"] as! String
                        ],
                        "isAppStoreBuild": true,//isAppStoreBuild(),
                        "isJailbroken": false,//isJailBroken(),
                        "language": NSLocale.preferredLanguages[0].lowercased(),
                        "networkTypeName": PsiphonCommon.getNetworkType()
                    ]
                    ] as [String:Any]
                feedbackBlob["DiagnosticInfo"] = diagnosticInfo as AnyObject?
            }
            
            // Generate random feedback ID
            var rndmHexId: String = ""
            
            if let randomBytes = PsiphonCommon.getRandomBytes(numBytes: 8) {
                // Turn randomBytes into array of hexadecimal strings
                // Join array of strings into single string
                // http://jamescarroll.xyz/2015/09/09/safely-generating-cryptographically-secure-random-numbers-with-swift/
                rndmHexId = randomBytes.map({String(format: "%02hhX", $0)}).joined(separator: "")
            } else {
                throw PsiphonError.Runtime("Failed to generate random bytes for feeedback upload id")
            }
            
            feedbackBlob["Metadata"] = [
                "id": rndmHexId,
                "platform": "ios",
                "version": 1
                ] as AnyObject
            
            let jsonData = try JSONSerialization.data(withJSONObject: feedbackBlob)
            let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!
            
            // Get feedback upload config
            let pubKey = config["FEEDBACK_ENCRYPTION_PUBLIC_KEY"] as! String
            let uploadServer = config["FEEDBACK_DIAGNOSTIC_INFO_UPLOAD_SERVER"] as! String
            let uploadPath = config["FEEDBACK_DIAGNOSTIC_INFO_UPLOAD_PATH"] as! String
            let uploadServerHeaders = config["FEEDBACK_DIAGNOSTIC_INFO_UPLOAD_SERVER_HEADERS"] as! String

            // Async upload
            DispatchQueue.global().async(execute: {
                PsiphonTunnel.sendFeedback(jsonString, connectionConfig: psiphonConfig, publicKey: pubKey, uploadServer: uploadServer, uploadPath: uploadPath, uploadServerHeaders: uploadServerHeaders)
            })
        } catch PsiphonError.Runtime(let error) {
            let statusEntry = StatusEntry(id: self.description(), formatArgs: [], throwable: Throwable(message: error, stackTrace: Thread.callStackSymbols), sensitivity: StatusEntry.SensitivityLevel.NOT_SENSITIVE, priority: StatusEntry.PriorityLevel.ERROR)
            PsiphonData.sharedInstance.addStatusEntry(entry:statusEntry)
        } catch(let unknownError) {
            let statusEntry = StatusEntry(id: self.description(), formatArgs: [], throwable: Throwable(message: unknownError.localizedDescription, stackTrace: Thread.callStackSymbols), sensitivity: StatusEntry.SensitivityLevel.NOT_SENSITIVE, priority: StatusEntry.PriorityLevel.ERROR)
            PsiphonData.sharedInstance.addStatusEntry(entry:statusEntry)
        }
    }
    
    class func gatherDeviceInfo() -> Dictionary<String, String> {
        var deviceInfo: Dictionary<String, String> = [:]
        
        // Get device for profiling
        let device = UIDevice.current
        
        let userInterfaceIdiom = device.userInterfaceIdiom
        var userInterfaceIdiomString = ""
        
        switch userInterfaceIdiom {
        case UIUserInterfaceIdiom.unspecified:
            userInterfaceIdiomString = "unspecified"
        case UIUserInterfaceIdiom.phone:
            userInterfaceIdiomString = "phone"
        case UIUserInterfaceIdiom.pad:
            userInterfaceIdiomString = "pad"
        case UIUserInterfaceIdiom.tv:
            userInterfaceIdiomString = "tv"
        case UIUserInterfaceIdiom.carPlay:
            userInterfaceIdiomString = "carPlay"
        }
        
        deviceInfo["systemName"] = device.systemName
        deviceInfo["systemVersion"] = device.systemVersion
        deviceInfo["model"] = device.model
        deviceInfo["localizedModel"] = device.localizedModel
        deviceInfo["userInterfaceIdiom"] = userInterfaceIdiomString
        deviceInfo["identifierForVendor"] = device.identifierForVendor!.uuidString
        
        return deviceInfo
    }
}
