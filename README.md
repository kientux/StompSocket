# StompSocket

STOMP WebSocket client.

- Based on `StompClientLib`
- Come with a default WebSocket implementation: `FoundationWebSocket`, it uses `URLSessionWebSocketTask` which is available for iOS 13+, macOS 10.15+ only
- If you want to use your own WebSocket implementation (SocketRocket, Starscream...), just conforms to `WebSocketProtocol`
