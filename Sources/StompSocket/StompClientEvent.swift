//
//  StompClientEvent.swift
//  StompSocket
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

public enum StompClientEvent {
    case connected
    case disconnected
    case message(body: String?, headers: [String: String]?, destination: String)
    case receipt(receiptId: String)
    case error(description: String, detailMessage: String?)
    case sentPing
}
