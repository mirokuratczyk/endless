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


class Throwable : NSObject {
    private var Message: String // Error.localizedDescription in most cases
    private var StackTrace: [String] // Thread.callStackSymbols()
    
    public init (message: String, stackTrace: [String]) {
        Message = message
        StackTrace = stackTrace
    }
    
    public func getMessage() -> String {
        return Message
    }
    
    public func getStackTrace() -> [String] {
        return StackTrace
    }
}

// Convert timestamp to shortened human readible format for display
func timestampForDisplay(timestamp: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current
    dateFormatter.dateFormat = "HH:mm:ss"
    return dateFormatter.string(from: timestamp)
}

class StatusEntry : NSObject {
    private var Timestamp: Date
    private var Id: String
    private var Sensitivity: StatusEntry.SensitivityLevel
    private var FormatArgs: [AnyObject]?
    private var Throwable: Throwable?
    private var Priority: StatusEntry.PriorityLevel
    
    @objc public enum SensitivityLevel: Int {
        /**
         * The log does not contain sensitive information.
         */
        case NOT_SENSITIVE
        /**
         * The log message itself is sensitive information.
         */
        case SENSITIVE_LOG
        /**
         * The format arguments to the log messages are sensitive, but the
         * log message itself is not.
         */
        case SENSITIVE_FORMAT_ARGS
    }
    
    @objc public enum PriorityLevel: Int {
        case VERBOSE = 2
        case DEBUG
        case INFO
        case WARN
        case ERROR
        case ASSERT
    }
    
    public init(id: String, formatArgs: [AnyObject]?, throwable: Throwable?, sensitivity: SensitivityLevel, priority: PriorityLevel) {
        Timestamp = Date()
        Id = id
        Sensitivity = sensitivity
        FormatArgs = formatArgs
        Throwable = throwable
        Priority = priority
    }

    // Return format args if they are not sensitive
    public func getFormatArgs() -> [AnyObject]? {
        if (self.getSensitivity() == StatusEntry.SensitivityLevel.SENSITIVE_FORMAT_ARGS) {
            return []
        } else {
            return self.FormatArgs
        }
    }
    
    public func getId() -> String {
        return self.Id
    }
    
    public func getPriority() -> Int {
        return self.Priority.rawValue
    }
    
    func getSensitivity() -> StatusEntry.SensitivityLevel {
        return self.Sensitivity
    }
    
    func getThrowable() -> Throwable? {
        return self.Throwable
    }
    
    public func getTimestamp() -> String {
        return self.Timestamp.iso8601
    }
    
    public func getTimestampForDisplay() -> String {
        return timestampForDisplay(timestamp: self.Timestamp)
    }
}

class DiagnosticEntry : NSObject {
    private var Timestamp: Date
    private var Msg: String
    private var Data: [String:AnyObject]
    
    private init(msg: String, nameValuePairs: AnyObject...) {
        assert(nameValuePairs.count % 2 == 0)
        
        Timestamp = Date()
        Msg = msg
        
        var jsonObject: [String:AnyObject] = [:]
        
        for i in 0...nameValuePairs.count/2-1 {
            jsonObject[nameValuePairs[i*2] as! String] = nameValuePairs[i*2+1]
        }
        
        Data = jsonObject
    }
    
    public init(msg: String) {
        let result = DiagnosticEntry(msg: msg, nameValuePairs: "msg" as AnyObject, msg as AnyObject)
        Timestamp = result.Timestamp
        Msg = result.Msg
        Data = result.Data
    }
    
    public func getTimestamp() -> String {
        return self.Timestamp.iso8601
    }
    
    public func getData() -> [String:AnyObject] {
        return self.Data
    }
    
    public func getMsg() -> String {
        return self.Msg
    }
    
    public func getTimestampForDisplay() -> String {
        return timestampForDisplay(timestamp: self.Timestamp)
    }
}

class PsiphonData: NSObject {
    
    private var statusHistory: [StatusEntry] = []
    private var diagnosticHistory: [DiagnosticEntry] = []
    static let sharedInstance = PsiphonData()
    
    override private init() {
        super.init()
        
        // Add observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(receivedNewLogEntryNotification(aNotification:)),
            name: Notification.Name.init(Constants.Notifications.NewLogEntry),
            object: nil)
    }
    
    // Don't need to check notification.name.rawvalue, because of observer pattern
    func receivedNewLogEntryNotification(aNotification: Notification) {
        /*let result: Result<String> = aNotification.getWithKey(key: Constants.Keys.LogEntry)
        
        switch result {
        case let .Value(message):
            if (message == Constants.Notifications.Connected) {
                noticeConnectionEstablished()
            } else {
                self.addDiagnosticEntry(diagnosticEntry: DiagnosticEntry(msg: message))
            }
        case let .Error(error):
            print(error)
        }*/
    }
    
    // Notify LogViewController that a new entry has been added
    func noticeLogAdded() {
        let notif = Notification.init(name: Notification.Name.init(rawValue:Constants.Notifications.DisplayLogEntry), object: nil, userInfo: nil)
        NotificationQueue.default.enqueue(notif, postingStyle: NotificationQueue.PostingStyle.now)
    }
    
    // TODO: remove?
    func noticeConnectionEstablished() {
        let notif = Notification.init(name: Notification.Name.init(rawValue:Constants.Notifications.ConnectionEstablished), object: nil, userInfo: nil)
        NotificationQueue.default.enqueue(notif, postingStyle: NotificationQueue.PostingStyle.now)
    }
    
    func addDiagnosticEntry(diagnosticEntry: DiagnosticEntry) {
        self.diagnosticHistory.append(diagnosticEntry)
        noticeLogAdded()
    }
    
    func addStatusEntry(entry: StatusEntry) {
        self.statusHistory.append(entry)
        noticeLogAdded()
    }
    
    func getDiagnosticHistory() -> [DiagnosticEntry] {
        return self.diagnosticHistory
    }
    
    func getDiagnosticLogs() -> [String] {
        return getDiagnosticLogs(n: nil)
    }

    // Get last `n` diagnostic logs for display
    func getDiagnosticLogs(n: Int?) -> [String] {
        var entries: [DiagnosticEntry] = []
        
        if let numEntries = n {
            entries = Array<DiagnosticEntry>(self.diagnosticHistory.suffix(numEntries))
        } else {
            entries = self.diagnosticHistory
        }
        return entries.map { ( $0 ).getTimestampForDisplay() + " " + ( $0 ).getMsg() } // map to string array of formatted entries for display
    }
    
    // Return status history with sensitive logs removed
    func getStatusHistory() -> [StatusEntry] {
        return self.statusHistory.filter { ($0).getSensitivity() != StatusEntry.SensitivityLevel.SENSITIVE_LOG }
    }
    
    // Return array of status entries formatted as strings for display
    func getStatusHistoryForDisplay() -> [String] {
        let statusHistory = self.statusHistory.filter { ($0).getSensitivity() != StatusEntry.SensitivityLevel.SENSITIVE_LOG }
        var stringsForDisplay: [String] = []
        
        for entry in statusHistory {
            var infoString: String = ""
            // Apply format args to string if provided
            if let formatArgs = entry.getFormatArgs() {
                // Need to downcast args to CVarArg for ingestion by String(format:String, arguments: [CVarArg])
                var args: [CVarArg] = []
                for arg in formatArgs {
                    if let cVarArg = arg as? CVarArg {
                        args.append(cVarArg)
                    } else {
                        // Nothing for now
                    }
                }
                infoString = String(format:entry.getId(), arguments:args)
            } else {
                infoString = entry.getId()
            }
            // Generate string for display
            let stringForDisplay = entry.getTimestampForDisplay() + " " + infoString
            stringsForDisplay.append(stringForDisplay)
        }
        return stringsForDisplay
    }
}
