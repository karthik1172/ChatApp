import Foundation
import Network
import Combine

class WebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var isConnected = false
    @Published var isOffline = false
    
    private var webSocket: URLSessionWebSocketTask?
    private let url = URL(string: "wss://demo.piesocket.com/v3/channel_123?api_key=VCXCEuvhGcBDP7XhiJJUDvR1e1D3eiVjgZ9VRiaV&notify_self")!
    private var urlSession: URLSession!
    private let monitor = NWPathMonitor()
    
    private let mainQueue = DispatchQueue.main
    private let backgroundQueue = DispatchQueue(label: "WebSocketQueue")
    
    override init() {
        super.init()
        
        urlSession = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: OperationQueue()
        )
        
        setupNetworkMonitoring()
        connect()
    }
}

// MARK: - Connection Handling
extension WebSocketManager {
    
    func connect() {
        guard !isConnected else {
            print("⚠️ Already connected, skipping reconnect.")
            return
        }
        guard !isOffline else {
            print("📵 Offline, not connecting.")
            return
        }

        webSocket = urlSession.webSocketTask(with: url)
        webSocket?.resume()

        print("📡 Trying WebSocket connection…")
    }
    
    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
    }
}

// MARK: - Send + Receive
extension WebSocketManager {
    
    func send(message: String) {
        guard isConnected else {
            print("⚠️ Not connected, cannot send: \(message)")
            return
        }
        
        webSocket?.send(.string(message)) { error in
            if let error = error {
                print("❌ Send failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
            }
        }
    }
    
    func receive() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let text):
                    print("📩 Received: \(text)")
                    NotificationCenter.default.post(
                        name: .WebSocketMessageReceived,
                        object: text
                    )
                case .data(let data):
                    print("📩 Received binary data: \(data)")
                default: break
                }
                
                self.receive() // continue listening
                
            case .failure(let error):
                print("❌ Receive failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                
                // Try reconnect
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.connect()
                }
            }
        }
    }
    
    func ping() {
        webSocket?.sendPing { error in
            if let error = error {
                print("⚠️ Ping error: \(error.localizedDescription)")
            } else {
                print("🏓 Ping successful")
            }
        }
    }
}

// MARK: - Delegate Callbacks
extension WebSocketManager {
    
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        
        print("🟢 WebSocket Connected")
        DispatchQueue.main.async {
            self.isConnected = true
        }
        receive()
        ping()
    }
    
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        
        print("🔴 WebSocket Closed")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

// MARK: - Network Monitoring
extension WebSocketManager {
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            
            DispatchQueue.main.async {
                self.isOffline = (path.status != .satisfied)
                
                if self.isOffline {
                    print("📵 Network offline — disconnecting socket")
                    self.disconnect()
                } else {
                    print("🌐 Network online — reconnecting…")
                    self.connect()
                }
            }
        }
        
        monitor.start(queue: backgroundQueue)
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let WebSocketMessageReceived = Notification.Name("WebSocketMessageReceived")
}
