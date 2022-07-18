//
//  BleWrapper.swift
//
//  Created by Dante Puglisi on 7/13/22.
//

import Foundation
import BleTransport
import os
import JavaScriptCore

public typealias EmptyResponse = (()->())
public typealias DictionaryResponse = (([AnyHashable: Any])->())
public typealias StringResponse = ((String)->())
public typealias JSValueResponse = ((JSValue)->())

open class BleWrapper {
    
    public var bleConnected = false {
        didSet {
            if bleConnected && openAppWhenConnectedAgain {
                Task() {
                    do {
                        try await openApp()
                        openAppIfNeededCompletion?(.success(()))
                    } catch {
                        if let error = error as? BleTransportError {
                            openAppIfNeededCompletion?(.failure(error))
                        }
                    }
                }
            }
        }
    }
    
    var openAppWhenConnectedAgain = false
    var openAppIfNeededCompletion: ((Result<Void, BleTransportError>) -> Void)? = nil
    
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
    
    open func openApp(name: String) async throws {
        openAppWhenConnectedAgain = false
        return try await withCheckedThrowingContinuation { continuation in
            openApp(name: name) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error)
            }
        }
    }
    
    open func closeApp() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            closeApp() {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error)
            }
        }
    }
    
    public func getAppAndVersion() async throws -> AppInfo {
        return try await withCheckedThrowingContinuation { continuation in
            self.getAppAndVersion { response in
                continuation.resume(returning: response)
            } failure: { error in
                continuation.resume(throwing: error)
            }
        }
    }
    
    public func openAppIfNeeded(name: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            openAppIfNeeded(name) { result in
                switch result {
                case .success(_):
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private methods
    private func openApp(name: String, success: @escaping EmptyResponse, failure: @escaping ErrorResponse) {
        let nameData = Data(name.utf8)
        var data: [UInt8] = [0xe0, 0xd8, 0x00, 0x00]
        data.append(UInt8(nameData.count))
        data.append(contentsOf: nameData)
        let apdu = APDU(data: data)
        BleTransport.shared.exchange(apdu: apdu) { result in
            switch result {
            case .success(_):
                success()
            case .failure(let error):
                failure(error)
            }
        }
    }
    
    private func closeApp(success: @escaping EmptyResponse, failure: @escaping ErrorResponse) {
        let apdu = APDU(data: [0xb0, 0xa7, 0x00, 0x00])
        BleTransport.shared.exchange(apdu: apdu) { result in
            switch result {
            case .success(_):
                success()
            case .failure(let error):
                failure(error)
            }
        }
    }
    
    private func getAppAndVersion(success: @escaping ((AppInfo)->()), failure: @escaping ErrorResponse) {
        let apdu = APDU(data: [0xb0, 0x01, 0x00, 0x00])
        BleTransport.shared.exchange(apdu: apdu) { result in
            switch result {
            case .success(let string):
                let data = string.UInt8Array()
                var i = 0
                let format = data[i]
                if format != 1 {
                    failure(BleTransportError.lowerLevelError(description: "getAppAndVersion: format not supported"))
                    return
                }
                i += 1
                let nameLength = Int(data[i])
                i += 1
                let nameData = data[i..<i+Int(nameLength)]
                i += nameLength
                let versionLength = Int(data[i])
                i += 1
                let versionData = data[i..<i+Int(versionLength)]
                i += versionLength
                guard let name = String(data: Data(nameData), encoding: .ascii) else { failure(BleTransportError.lowerLevelError(description: "Couldn't parse name")); return }
                guard let version = String(data: Data(versionData), encoding: .ascii) else { failure(BleTransportError.lowerLevelError(description: "Couldn't parse version")); return }
                success(AppInfo(name: name, version: version))
            case .failure(let error):
                failure(error)
            }
        }
    }
    
    private func openAppIfNeeded(_ name: String, completion: @escaping (Result<Void, BleTransportError>) -> Void) {
        Task() {
            do {
                let currentAppInfo = try await getAppAndVersion()
                if currentAppInfo.name != name {
                    if currentAppInfo.name == "BOLOS" {
                        try await openApp()
                        completion(.success(()))
                    } else {
                        openAppWhenConnectedAgain = true
                        openAppIfNeededCompletion = completion
                        try await closeApp()
                    }
                } else {
                    completion(.success(()))
                }
            } catch {
                if let error = error as? BleTransportError {
                    completion(.failure(error))
                }
            }
        }
    }
}

public struct AppInfo {
    let name: String
    let version: String
}
