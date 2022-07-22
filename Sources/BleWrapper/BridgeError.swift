//
//  BridgeError.swift
//
//  Created by Dante Puglisi on 7/22/22.
//

import Foundation
import JavaScriptCore
import BleTransport

public struct BridgeError: Error {
    let id: String?
    let name: String
    let message: String
    let statusCode: Int?
    
    static func fromJSValue(_ jsValue: JSValue) -> Error {
        guard let dict = jsValue.toDictionary() else { return BleTransportError.lowerLevelError(description: jsValue.debugDescription) }
        guard let name = dict["name"] as? String else { return BleTransportError.lowerLevelError(description: jsValue.debugDescription) }
        guard let message = dict["message"] as? String else { return BleTransportError.lowerLevelError(description: jsValue.debugDescription) }
        
        let id = dict["id"] as? String
        let statusCode = dict["statusCode"] as? Int
        
        return BridgeError(id: id, name: name, message: message, statusCode: statusCode)
    }
}
