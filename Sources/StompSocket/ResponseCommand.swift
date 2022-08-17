//
//  ResponseCommand.swift
//  StompSocket
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

enum ResponseCommand: String {
    case connected = "CONNECTED"
    case message = "MESSAGE"
    case receipt = "RECEIPT"
    case error = "ERROR"
}
