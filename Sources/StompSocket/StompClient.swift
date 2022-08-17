//
//  StompClient.swift
//  StompSocket
//  
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

public class StompClient {
    private var socket: WebSocketProtocol?
    
    private var sessionId: String?
    private var connectionHeaders: [CommandHeader: String]?
    
    private var urlRequest: URLRequest!
    
    private var reconnectTimer : Timer?
    private var pingTimer: Timer?
    
    public var eventListener: ((StompClientEvent) -> Void)?
    public var isCertificateCheckEnabled = true
    public var isAutoPingEnabled: Bool = true
    public var autoPingInterval: TimeInterval = 10
    
    public var logger: Logger = DefaultLogger()
    
    public var isConnected: Bool {
        socket?.isConnected ?? false
    }
    
    private let socketBuilder: () -> WebSocketProtocol
    
    public init(socketBuilder: @escaping () -> WebSocketProtocol) {
        self.socketBuilder = socketBuilder
    }
    
    public func openSocketWithURLRequest(request: URLRequest,
                                         connectionHeaders: [CommandHeader: String]? = nil) {
        self.connectionHeaders = connectionHeaders
        self.urlRequest = request
        self.openSocket()
    }
    
    private func openSocket() {
        socket = socketBuilder()
        
        socket?.eventListener = { [weak self] event in
            self?.handle(event: event)
        }
        
        socket?.connect(request: urlRequest)
    }
    
    private func handle(event: WebSocketEvent) {
        switch event {
        case .connected:
            if isAutoPingEnabled {
                pingTimer?.invalidate()
                pingTimer = Timer.scheduledTimer(timeInterval: autoPingInterval,
                                                 target: self,
                                                 selector: #selector(ping),
                                                 userInfo: nil,
                                                 repeats: true)
            } else {
                pingTimer?.invalidate()
            }
            
            logger.debug(message: "[StompClient] WebSocket is connected, send connect frame")
            sendConnectFrame()
            
        case .disconnected(let code, let reason):
            logger.debug(message: "[StompClient] WebSocket disconnected with code: \(code), reason: \(reason ?? "nil")")
            pingTimer?.invalidate()
            eventListener?(.disconnected)
            
        case .text(let text):
            processString(string: text)
            
        case .data(let data):
            if let msg = String(data: data, encoding: .utf8) {
                processString(string: msg)
            }
        case .error(let error):
            logger.error(message: "[StompClient] WebSocket error occurred: \(String(describing: error))")
            pingTimer?.invalidate()
            eventListener?(.error(description: error.localizedDescription,
                                  detailMessage: nil))
        }
    }
    
    private func processString(string: String) {
        var contents = string.components(separatedBy: "\n")
        if contents.first == "" {
            contents.removeFirst()
        }
        
        if let commandValue = contents.first,
           let command = ResponseCommand(rawValue: commandValue) {
            var headers = [String: String]()
            var body = ""
            var hasHeaders  = false
            
            contents.removeFirst()
            for line in contents {
                if hasHeaders == true {
                    body += line
                } else {
                    if line == "" {
                        hasHeaders = true
                    } else {
                        let parts = line.components(separatedBy: ":")
                        if let key = parts.first {
                            headers[key] = parts.dropFirst().joined(separator: ":")
                        }
                    }
                }
            }
            
            // Remove the garbage from body
            if body.hasSuffix("\0") {
                body = body.replacingOccurrences(of: "\0", with: "")
            }
            
            receiveFrame(command: command, headers: headers, body: body)
        }
    }
    
    private func closeSocket() {
        if socket != nil {
            // Close the socket
            socket?.disconnect()
            socket?.eventListener = nil
            socket = nil
        }
        
        eventListener?(.disconnected)
    }
    
    /*
     Main Connection Method to open socket
     */
    private func sendConnectFrame() {
        guard socket != nil else {
            openSocket()
            return
        }
        
        // Support for Spring Boot 2.1.x
        if connectionHeaders == nil {
            connectionHeaders = [.acceptVersion: "1.1,1.2"]
        } else {
            connectionHeaders?[.acceptVersion] = "1.1,1.2"
        }
        
        // at the moment only anonymous logins
        sendFrame(command: .connect, header: connectionHeaders, body: nil)
    }
    
    @objc private func ping() {
        socket?.ping()
        eventListener?(.sentPing)
    }
    
    private func sendFrame(command: Command, header: [CommandHeader: String]?, body: String?) {
        var frameString = ""
        frameString = command.rawValue + "\n"
        
        if let header = header {
            for (key, value) in header {
                frameString += key.rawValue
                frameString += ":"
                frameString += value
                frameString += "\n"
            }
        }
        
        if let body = body {
            frameString += body
        }
            
        frameString += "\n"
        
        frameString += StompConsts.controlChar
        
        logger.debug(message: "[StompClient] Websocket sendFrame: \(frameString)")
        socket?.send(string: frameString)
    }
    
    private func destinationFromHeader(header: [String: String]) -> String {
        header.first(where: { $0.key == "destination" })?.value ?? ""
    }
    
    private func receiveFrame(command: ResponseCommand, headers: [String: String], body: String?) {
        switch command {
        case .connected:
            if let sessId = headers[StompConsts.responseHeaderSession] {
                sessionId = sessId
            }
            
            eventListener?(.connected)
        case .message:
            eventListener?(.message(body: body, headers: headers, destination: destinationFromHeader(header: headers)))
        case .receipt:
            if let receiptId = headers[StompConsts.responseHeaderReceiptId] {
                eventListener?(.receipt(receiptId: receiptId))
            }
        case .error:
            if let msg = headers[StompConsts.responseHeaderErrorMessage] {
                eventListener?(.error(description: msg, detailMessage: body))
            }
        }
    }
    
    public func sendMessage(message: String,
                            toDestination destination: String,
                            withHeaders headers: [CommandHeader: String]?,
                            withReceipt receipt: String?) {
        var headersToSend = [CommandHeader: String]()
        if let headers = headers {
            headersToSend = headers
        }
        
        // Setting up the receipt.
        if let receipt = receipt {
            headersToSend[.receipt] = receipt
        }
        
        headersToSend[.destination] = destination
        
        // Setting up the content length.
        let contentLength = message.utf8.count
        headersToSend[.contentLength] = "\(contentLength)"
        
        // Setting up content type as plain text.
        if headersToSend[.contentType] == nil {
            headersToSend[.contentType] = "text/plain"
        }
        sendFrame(command: .send, header: headersToSend, body: message)
    }
    
    /*
     Main Subscribe Method with topic name
     */
    public func subscribe(destination: String) {
        subscribeToDestination(destination: destination, ackMode: .auto)
    }
    
    public func subscribeToDestination(destination: String, ackMode: AckMode) {
        var headers = [CommandHeader.destination: destination,
                       CommandHeader.ack: ackMode.rawValue,
                       CommandHeader.id: ""]
        if destination != "" {
            headers = [.destination: destination,
                       .ack: ackMode.rawValue,
                       .id: destination]
        }
        self.sendFrame(command: .subscribe, header: headers, body: nil)
    }
    
    public func subscribeWithHeader(destination: String, withHeader header: [CommandHeader: String]) {
        var headerToSend = header
        headerToSend[.destination] = destination
        sendFrame(command: .subscribe, header: headerToSend, body: nil)
    }
    
    /*
     Main Unsubscribe Method with topic name
     */
    public func unsubscribe(destination: String) {
        var headerToSend = [CommandHeader: String]()
        headerToSend[.id] = destination
        sendFrame(command: .unsubscribe, header: headerToSend, body: nil)
    }
    
    public func begin(transactionId: String) {
        var headerToSend = [CommandHeader: String]()
        headerToSend[.transaction] = transactionId
        sendFrame(command: .begin, header: headerToSend, body: nil)
    }
    
    public func commit(transactionId: String) {
        var headerToSend = [CommandHeader: String]()
        headerToSend[.transaction] = transactionId
        sendFrame(command: .commit, header: headerToSend, body: nil)
    }
    
    public func abort(transactionId: String) {
        var headerToSend = [CommandHeader: String]()
        headerToSend[.transaction] = transactionId
        sendFrame(command: .abort, header: headerToSend, body: nil)
    }
    
    public func ack(messageId: String) {
        var headerToSend = [CommandHeader: String]()
        headerToSend[.id] = messageId
        sendFrame(command: .ack, header: headerToSend, body: nil)
    }
    
    public func ack(messageId: String, withSubscription subscription: String) {
        var headerToSend = [CommandHeader: String]()
        headerToSend[.id] = messageId
        headerToSend[.subscription] = subscription
        sendFrame(command: .ack, header: headerToSend, body: nil)
    }
    
    /*
     Main Disconnection Method to close the socket
     */
    public func disconnect() {
        pingTimer?.invalidate()
        var headerToSend = [CommandHeader: String]()
        headerToSend[.disconnect] = String(Int(Date().timeIntervalSince1970))
        sendFrame(command: .disconnect, header: headerToSend, body: nil)
        // Close the socket to allow recreation
        self.closeSocket()
    }
    
    /// Reconnect every `time` seconds
    /// - Parameters:
    ///   - request: request
    ///   - connectionHeaders: connectionHeaders
    ///   - time: time interval, defaults to 10 seconds
    ///   - force: force reconnect even when websocket is currently connected. Defaults to `false`.
    public func reconnect(request: URLRequest,
                          connectionHeaders: [CommandHeader: String] = [:],
                          time: TimeInterval = 10,
                          force: Bool = false) {
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: time, repeats: true) { [weak self] _ in
            self?.reconnectLogic(request: request, connectionHeaders: connectionHeaders, force: force)
        }
    }
    
    private func reconnectLogic(request: URLRequest,
                                connectionHeaders: [CommandHeader: String] = [:],
                                force: Bool) {
        if !isConnected || force {
            openSocketWithURLRequest(request: request,
                                     connectionHeaders: connectionHeaders)
        }
    }
    
    public func stopReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

