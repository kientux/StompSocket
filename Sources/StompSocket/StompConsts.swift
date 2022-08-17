//
//  StompConsts.swift
//  StompSocket
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

struct StompConsts {
    static let controlChar = String(format: "%C", arguments: [0x00])
    
    // Header Response Keys
    static let responseHeaderSession = "session"
    static let responseHeaderReceiptId = "receipt-id"
    static let responseHeaderErrorMessage = "message"
}
