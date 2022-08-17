# StompSocket

STOMP WebSocket client.

- Based on `StompClientLib`
- Come with a default WebSocket implementation: `FoundationWebSocket`, it uses `URLSessionWebSocketTask` which is available for iOS 13+, macOS 10.15+ only
- If you want to use your own WebSocket implementation (SocketRocket, Starscream...), just conforms to `WebSocketProtocol`


### Usage:

```swift
let socketClient = StompClient(socketBuilder: {
    if #available(iOS 13.0, *) {
        return FoundationWebSocket()
    } else {
        fatalError("your ws implementation here!")
    }
})

// headers sent when connect
var connectionHeaders: [CommandHeader: String] = [.heartBeat: "10000,20000",
                                                  .acceptVersion: "1.1,1.2"]
var request = URLRequest(url: url)
request.timeoutInterval = 30

customHttpHeaders.forEach({
    request.setValue($0.value, forHTTPHeaderField: $0.key)
    connectionHeaders[.custom($0.key)] = $0.value
})

// auto ping every 10 seconds to keep connection open
socketClient.isAutoPingEnabled = true
socketClient.autoPingInterval = 10

// listen to ws event
socketClient.eventListener = { [unowned socketClient] event in
    switch event {
    case .connected:
        print("ws connected, subscribe now")
        socketClient.subscribe(destination: "/topic/hello")
    case .disconnected:
        print("ws disconnected")
    case .message(let body, let headers, let destination):
        print("ws received message: \(body ?? "")")
    case .receipt(let receiptId):
        print("ws received receiptId: \(receiptId)")
    case .error(let description, let detailMessage):
        print("ws received error: \(description), detailMessage: \(detailMessage ?? "")")
    case .sentPing:
        print("ws did sent ping")
    }
}

// connect
socketClient.openSocketWithURLRequest(request: request, 
                                      connectionHeaders: connectionHeaders)

// optional, auto reconnect every 30 seconds
socketClient.reconnect(request: request,
                       connectionHeaders: connectionHeaders,
                       time: 30,
                       force: false)

// disconnect
DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(60)) {
    socketClient.disconnect()
}
```
