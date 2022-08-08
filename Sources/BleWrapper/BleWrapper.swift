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
    
    public func parseBuffer(dict: [String: AnyObject]) -> [UInt8] {
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
    
    public func log(_ items: Any...) {
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
        BleTransport.shared.openAppIfNeeded(name) { result in
            switch result {
            case .success(_):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(BridgeError.fromError(error)))
            }
        }
    }
    
    open func getAppAndVersion(success: @escaping ((AppInfo) -> ()), failure: @escaping ErrorResponse) {
        BleTransport.shared.getAppAndVersion { result in
            success(result)
        } failure: { error in
            failure(BridgeError.fromError(error))
        }
    }
    
    public func jsValueAsError(_ jsValue: JSValue) -> Error {
        return BridgeError.fromJSValue(jsValue)
    }
}

/// Async implementations
extension BleWrapper {
    open func openAppIfNeeded(_ name: String) async throws {
        do {
            return try await BleTransport.shared.openAppIfNeeded(name)
        } catch {
            throw BridgeError.fromError(error)
        }
    }
    
    open func getAppAndVersion() async throws -> AppInfo {
        do {
            return try await BleTransport.shared.getAppAndVersion()
        } catch {
            throw BridgeError.fromError(error)
        }
    }
}
