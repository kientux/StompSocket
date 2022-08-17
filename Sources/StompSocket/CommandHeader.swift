//
//  CommandHeader.swift
//  StompSocket
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

public enum CommandHeader: Hashable {
    case receipt
    case destination
    case id
    case contentLength
    case contentType
    case ack
    case transaction
    case subscription
    case disconnect
    case disconnected
    case heartBeat
    case acceptVersion
    case custom(String)
    
    var rawValue: String {
        switch self {
        case .receipt: return "receipt"
        case .destination: return "destination"
        case .id: return "id"
        case .contentLength: return "content-length"
        case .contentType: return "content-type"
        case .ack: return "ack"
        case .transaction: return "transaction"
        case .subscription: return "subscription"
        case .disconnect: return "disconnect"
        case .disconnected: return "disconnected"
        case .heartBeat: return "heart-beat"
        case .acceptVersion: return "accept-version"
        case .custom(let val): return val
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
