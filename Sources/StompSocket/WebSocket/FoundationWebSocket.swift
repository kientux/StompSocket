//
//  FoundationWebSocket.swift
//  StompClientLib
//
//  Created by Kien Nguyen on 17/08/2022.
//

import Foundation

@available(iOS 13.0, macOS 10.15, *)
public class FoundationWebSocket: NSObject, WebSocketProtocol, URLSessionWebSocketDelegate {
    private var task: URLSessionWebSocketTask?
    private lazy var session = URLSession(configuration: .default,
                                          delegate: self,
                                          delegateQueue: .main)
    
    public var logger: Logger = DefaultLogger()
    
    public var eventListener: ((WebSocketEvent) -> Void)?
    
    public var isConnected: Bool {
        task != nil && task?.state == .running
    }
    
    public func connect(request: URLRequest) {
        task = session.webSocketTask(with: request)
        task?.resume()
        
        observeMessage()
    }
    
    public func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }
    
    public func send(string: String) {
        checkState()
        
        task?.send(.string(string), completionHandler: { [weak self] error in
            if let error = error {
                self?.logger.error(message: "[FoundationWebSocket] Error send string: \(error)")
            }
        })
    }
    
    public func send(data: Data) {
        checkState()
        
        task?.send(.data(data), completionHandler: { [weak self] error in
            if let error = error {
                self?.logger.error(message: "[FoundationWebSocket] Error send data: \(error)")
            }
        })
    }
    
    public func ping() {
        checkState()
        
        task?.sendPing(pongReceiveHandler: { [weak self] error in
            if let error = error {
                self?.logger.error(message: "[FoundationWebSocket] Error send ping: \(error)")
            } else {
                self?.logger.debug(message: "[FoundationWebSocket] Received pong")
            }
        })
    }
    
    private func observeMessage() {
        checkState()
        
        task?.receive(completionHandler: { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let s):
                    self?.logger.debug(message: "[FoundationWebSocket] Received text message: \(s)")
                    self?.eventListener?(.text(text: s))
                case .data(let data):
                    if let s = String(data: data, encoding: .utf8) {
                        self?.logger.debug(message: "[FoundationWebSocket] Received data message: \(s)")
                        self?.eventListener?(.text(text: s))
                    } else {
                        self?.logger.debug(message: "[FoundationWebSocket] Received data message: \(data)")
                        self?.eventListener?(.data(data: data))
                    }
                @unknown default:
                    self?.logger.debug(message: "[FoundationWebSocket] Received unknown message type")
                }
            case .failure(let error):
                self?.logger.error(message: "[FoundationWebSocket] Received error: \(error)")
                self?.eventListener?(.error(error: error))
            }
            
            // completionHandler is removed right after receive message
            // so we have to observe message again every time.
            if self?.task?.state == .running {
                self?.observeMessage()
            }
        })
    }
    
    private func checkState() {
        if task?.state != .running {
            logger.debug(message: "FoundationWebSocket is not running. Current state: \(task?.state.name ?? "")")
        }
    }
    
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didOpenWithProtocol protocol: String?) {
        logger.debug(message: "FoundationWebSocket didOpenWithProtocol \(`protocol` ?? "")")
        eventListener?(.connected)
    }
    
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                           reason: Data?) {
        let reasonString = reason == nil ? nil : String(data: reason!, encoding: .utf8)
        logger.debug(message: "FoundationWebSocket didCloseWithCode \(closeCode.name) - reason: \(reasonString ?? "")")
        eventListener?(.disconnected(code: closeCode.rawValue, reason: reasonString))
        task = nil
    }
}

@available(iOS 13.0, macOS 10.15, *)
extension URLSessionWebSocketTask.CloseCode {
    var name: String {
        switch self {
        case .invalid:
            return "invalid"
        case .normalClosure:
            return "normalClosure"
        case .goingAway:
            return "goingAway"
        case .protocolError:
            return "protocolError"
        case .unsupportedData:
            return "unsupportedData"
        case .noStatusReceived:
            return "noStatusReceived"
        case .abnormalClosure:
            return "abnormalClosure"
        case .invalidFramePayloadData:
            return "invalidFramePayloadData"
        case .policyViolation:
            return "policyViolation"
        case .messageTooBig:
            return "messageTooBig"
        case .mandatoryExtensionMissing:
            return "mandatoryExtensionMissing"
        case .internalServerError:
            return "internalServerError"
        case .tlsHandshakeFailure:
            return "tlsHandshakeFailure"
        @unknown default:
            return "@unknown"
        }
    }
}

extension URLSessionTask.State {
    var name: String {
        switch self {
        case .running: return "running"
        case .canceling: return "canceling"
        case .completed: return "completed"
        case .suspended: return "suspended"
        @unknown default:
            return "@unknown"
        }
    }
}
