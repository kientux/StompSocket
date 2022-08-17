//
//  Command.swift
//  StompSocket
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

enum Command: String {
    case connect = "CONNECT"
    case send = "SEND"
    case subscribe = "SUBSCRIBE"
    case unsubscribe = "UNSUBSCRIBE"
    case begin = "BEGIN"
    case commit = "COMMIT"
    case abort = "ABORT"
    case ack = "ACK"
    case disconnect = "DISCONNECT"
    case ping = "\n"
}
