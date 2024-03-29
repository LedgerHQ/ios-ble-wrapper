//
//  TransportJS.swift
//
//  Created by Dante Puglisi on 7/13/22.
//

import Foundation
import BleTransport
import JavaScriptCore

typealias JSValueBlock = (@convention(block) (JSValue) -> Void)

@objc protocol TransportJSExport: JSExport {
    static func create() -> TransportJS
    
    func exchange(_ buffer: [UInt8]) -> JSValueBlock
    func send(_ cla: UInt8, _ ins: UInt8, _ p1: UInt8, _ p2: UInt8, _ data: [UInt8]) -> JSValueBlock
}

@objc public class TransportJS : NSObject, TransportJSExport {
    
    let transport: BleTransportProtocol = BleTransport.shared
    
    class func create() -> TransportJS {
        return TransportJS()
    }
    
    func exchange(_ buffer: [UInt8]) -> (@convention(block) (JSValue) -> Void) {
        let block: JSValueBlock = { callback in
            self.transport.exchange(apdu: APDU(data: buffer)) { result in
                switch result {
                case .success(let response):
                    callback.call(withArguments: [response.UInt8Array(), ""])
                case .failure(let error):
                    callback.call(withArguments: ["", "ERROR: \(error.localizedDescription)"])
                }
            }
        }
        
        return block
    }
    
    func send(_ cla: UInt8, _ ins: UInt8, _ p1: UInt8, _ p2: UInt8, _ data: [UInt8]) -> (@convention(block) (JSValue) -> Void) {
        var apdu = [cla, ins, p1, p2, UInt8(data.count)]
        apdu.append(contentsOf: data)
        let block: JSValueBlock = { callback in
            self.transport.exchange(apdu: APDU(data: apdu)) { result in
                switch result {
                case .success(let response):
                    callback.call(withArguments: [response.UInt8Array(), ""])
                case .failure(let error):
                    callback.call(withArguments: ["", "ERROR: \(error.localizedDescription)"])
                }
            }
        }
        
        return block
    }
}
