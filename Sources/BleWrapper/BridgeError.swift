//
//  BridgeError.swift
//
//  Created by Dante Puglisi on 7/22/22.
//

import Foundation
import JavaScriptCore
import BleTransport

public struct BridgeError: Error {
    public let id: String?
    public let name: String
    public let message: String
    public let statusCode: Int?
    
    // MARK: - Static methods
    public static func fromJSValue(_ jsValue: JSValue) -> Error {
        guard let dict = jsValue.toDictionary() else { return BleTransportError.lowerLevelError(description: jsValue.debugDescription) }
        guard let name = dict["name"] as? String else { return BleTransportError.lowerLevelError(description: jsValue.debugDescription) }
        guard let message = dict["message"] as? String else { return BleTransportError.lowerLevelError(description: jsValue.debugDescription) }
        
        let id = dict["id"] as? String
        let statusCode = dict["statusCode"] as? Int
        
        return BridgeError(id: id, name: name, message: message, statusCode: statusCode)
    }
    
    public static func fromError(_ error: Error) -> Error {
        if let error = error as? BleTransportError {
            return BridgeError(id: nil, name: "TransportError", message: error.localizedDescription, statusCode: nil)
        } else if let error = error as? BleStatusError {
            var status: Int?
            if let errorStatus = error.status() {
                status = Int(errorStatus, radix: 16)
            }
            return BridgeError(id: nil, name: "TransportStatusError", message: error.localizedDescription, statusCode: status)
        } else {
            return error
        }
    }
}
