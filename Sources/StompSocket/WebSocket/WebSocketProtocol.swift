//
//  WebSocketProtocol.swift
//  StompClientLib
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

public protocol WebSocketProtocol {
    func connect(request: URLRequest)
    func disconnect()
    
    var isConnected: Bool { get }
    
    var eventListener: ((WebSocketEvent) -> Void)? { get set }
    
    func send(string: String)
    func send(data: Data)
    func ping()
}

public enum WebSocketEvent {
    case connected
    case disconnected(code: Int, reason: String?)
    case text(text: String)
    case data(data: Data)
    case error(error: Error)
}
