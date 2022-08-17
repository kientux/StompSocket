//
//  Logger.swift
//  
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

public protocol Logger {
    func debug(message: @autoclosure () -> Any)
    func error(message: @autoclosure () -> Any)
}

class DefaultLogger: Logger {
    func debug(message: @autoclosure () -> Any) {
        print(message())
    }
    
    func error(message: @autoclosure () -> Any) {
        print(message())
    }
}
