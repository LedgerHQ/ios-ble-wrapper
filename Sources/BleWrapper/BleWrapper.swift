//
//  BleWrapper.swift
//
//  Created by Dante Puglisi on 7/13/22.
//

import Foundation
import os
import JavaScriptCore
import BleTransport

public typealias EmptyResponse = (()->())
public typealias DictionaryResponse = (([AnyHashable: Any])->())
public typealias StringResponse = ((String)->())
public typealias JSValueResponse = ((JSValue)->())
public typealias ErrorResponse = ((Error)->())

open class BleWrapper {
    
    public init() {
        
    }
    
    // MARK: - Open methods
    open func parseBuffer(dict: [String: AnyObject]) -> [UInt8] {
        var dataTuple = [(pos: Int, value: UInt8)]()
        for item in dict {
            /// We only keep the byte items
            if let itemValue = item.value as? UInt8, let itemKey = Int(item.key) {
                dataTuple.append((pos: itemKey, value: itemValue))
            }
        }
        dataTuple.sort(by: { A, B in A.pos < B.pos })
        return dataTuple.map({ $0.value })
    }
    
    open func log(_ items: Any...) {
        let stringToLog = (items.compactMap({ "\($0)" }).joined(separator: " "))
        if #available(iOS 14.0, *) {
            let logger = Logger(subsystem: "com.LedgerHQ", category: "ios-ble-wrapper")
            logger.log("\(stringToLog)")
        } else {
            let log = OSLog.init(subsystem: "com.LedgerHQ", category: "ios-ble-wrapper")
            os_log("%s", log: log, stringToLog)
        }
    }
    
    open func openAppIfNeeded(_ name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        BleTransport.shared.openAppIfNeeded(name, completion: completion)
    }
    
    open func closeApp(success: @escaping EmptyResponse, failure: @escaping ErrorResponse) {
        BleTransport.shared.closeApp(success: success, failure: failure)
    }
    
    open func getAppAndVersion(success: @escaping ((AppInfo) -> ()), failure: @escaping ErrorResponse) {
        BleTransport.shared.getAppAndVersion(success: success, failure: failure)
    }
}

/// Async implementations
extension BleWrapper {
    open func openAppIfNeeded(_ name: String) async throws {
        return try await BleTransport.shared.openAppIfNeeded(name)
    }
    
    open func closeApp() async throws {
        return try await BleTransport.shared.closeApp()
    }
    
    open func getAppAndVersion() async throws -> AppInfo {
        return try await BleTransport.shared.getAppAndVersion()
    }
}
