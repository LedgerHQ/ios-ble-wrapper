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
    
    public static func fromEnum(_ enumValue: Error) -> Error {
        if let enumValue = enumValue as? BleTransportError {
            return BridgeError(id: nil, name: "TransportError", message: enumValue.localizedDescription, statusCode: nil)
        } else if let enumValue = enumValue as? BleStatusError {
            var status: Int?
            if let enumStatus = enumValue.status() {
                status = Int(enumStatus)
            }
            return BridgeError(id: nil, name: "TransportStatusError", message: enumValue.localizedDescription, statusCode: status)
        } else {
            return enumValue
        }
    }
}
