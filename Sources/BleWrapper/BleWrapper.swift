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
public typealias ErrorResponse = ((BleTransportError)->())

open class BleWrapper {
    
    public init() {
        
    }
    
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
    
    open func openApp(name: String, success: @escaping EmptyResponse, failure: @escaping ErrorResponse) {
        let nameData = Data(name.utf8)
        var data: [UInt8] = [0xe0, 0xd8, 0x00, 0x00]
        data.append(UInt8(nameData.count))
        data.append(contentsOf: nameData)
        let apdu = APDU(data: data)
        BleTransport.shared.send(apdu: apdu) {
            success()
        } failure: { error in
            if let error = error {
                failure(error)
            }
        }
    }
    
    open func closeApp(success: @escaping EmptyResponse, failure: @escaping ErrorResponse) {
        let apdu = APDU(data: [0xb0, 0xa7, 0x00, 0x00])
        BleTransport.shared.send(apdu: apdu) {
            success()
        } failure: { error in
            if let error = error {
                failure(error)
            }
        }
    }
}
