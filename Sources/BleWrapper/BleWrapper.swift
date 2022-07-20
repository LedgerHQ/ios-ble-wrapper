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
public typealias ErrorResponse = ((Error)->())

public protocol BleConnectionDelegate {
    func createAgainAfterDisconnect(success: @escaping EmptyResponse, failure: @escaping ErrorResponse)
}

public enum BleWrapperError: Error {
    case userRejected
    case appNotAvailableInDevice
    case noStatus
    case formatNotSupported
    case couldNotParseResponseData
    case unknown
}

open class BleWrapper {
    
    var connectionDelegate: BleConnectionDelegate
    
    public init(connectionDelegate: BleConnectionDelegate) {
        self.connectionDelegate = connectionDelegate
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
    
    // MARK: - Async methods
    open func openApp(_ name: String) async throws {
        //openAppWithNameWhenConnectedAgain = nil
        return try await withCheckedThrowingContinuation { continuation in
            openApp(name) {
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
    
    public func openAppIfNeeded(_ name: String) async throws {
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
    
    // MARK: - Completion methods
    public func openApp(_ name: String, success: @escaping EmptyResponse, failure: @escaping ErrorResponse) {
        let errorCodes: [BleWrapperError: [String]] = [.userRejected: ["6985", "5501"], .appNotAvailableInDevice: ["6984", "6807"]]
        let nameData = Data(name.utf8)
        var data: [UInt8] = [0xe0, 0xd8, 0x00, 0x00]
        data.append(UInt8(nameData.count))
        data.append(contentsOf: nameData)
        let apdu = APDU(data: data)
        BleTransport.shared.exchange(apdu: apdu) { [weak self] result in
            switch result {
            case .success(let response):
                if let error = self?.parseStatus(response: response, errorCodes: errorCodes) {
                    failure(error)
                } else {
                    self?.connectionDelegate.createAgainAfterDisconnect {
                        success()
                    } failure: { error in
                        failure(error)
                    }
                }
            case .failure(let error):
                failure(error)
            }
        }
    }
    
    public func closeApp(success: @escaping EmptyResponse, failure: @escaping ErrorResponse) {
        let apdu = APDU(data: [0xb0, 0xa7, 0x00, 0x00])
        BleTransport.shared.exchange(apdu: apdu) { [weak self] result in
            switch result {
            case .success(_):
                self?.connectionDelegate.createAgainAfterDisconnect {
                    success()
                } failure: { error in
                    failure(error)
                }
            case .failure(let error):
                failure(error)
            }
        }
    }
    
    public func getAppAndVersion(success: @escaping ((AppInfo)->()), failure: @escaping ErrorResponse) {
        let apdu = APDU(data: [0xb0, 0x01, 0x00, 0x00])
        BleTransport.shared.exchange(apdu: apdu) { result in
            switch result {
            case .success(let string):
                let data = string.UInt8Array()
                var i = 0
                let format = data[i]
                if format != 1 {
                    failure(BleWrapperError.formatNotSupported)
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
                guard let name = String(data: Data(nameData), encoding: .ascii) else { failure(BleWrapperError.couldNotParseResponseData); return }
                guard let version = String(data: Data(versionData), encoding: .ascii) else { failure(BleWrapperError.couldNotParseResponseData); return }
                success(AppInfo(name: name, version: version))
            case .failure(let error):
                failure(error)
            }
        }
    }
    
    public func openAppIfNeeded(_ name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task() {
            do {
                let currentAppInfo = try await getAppAndVersion()
                if currentAppInfo.name != name {
                    if currentAppInfo.name == "BOLOS" {
                        try await openApp(name)
                        completion(.success(()))
                    } else {
                        try await closeApp()
                        try await openApp(name)
                        completion(.success(()))
                    }
                } else {
                    completion(.success(()))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    fileprivate func parseStatus(response: String, errorCodes: [BleWrapperError: [String]]) -> BleWrapperError? {
        let status = response.suffix(4)
        if status.count == 4 {
            if status == "9000" {
                return nil
            } else {
                if let error = errorCodes.first(where: { $0.value.contains(String(status)) })?.key {
                    return error
                } else {
                    return .unknown
                }
            }
        } else {
            return .noStatus
        }
    }
}

public struct AppInfo {
    let name: String
    let version: String
}
