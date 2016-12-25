import Foundation

class Connector: WebSocketDelegate {
    var socket: WebSocket
    var observations: [Double] = []
    
    init () {
        socket = WebSocket(url: URL(string: "wss://latency.x5e.qa/websocket?9007199254740992")!)
        socket.delegate = self
        socket.connect()
    }
    
    func websocketDidConnect(socket: WebSocket) {
        print("websocket is connected")
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        print("websocket is disconnected: \(error?.localizedDescription)")
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        // print("got some text: \(text)")
        socket.write(string: text)
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        //print("got some data: \(data.count)")
        let d:Double = decode(data: data as NSData)
        observations.append(d)
        observations.sort()
        show(d)
    }
    
    func quantile(_ p: Double) -> Double {
        guard observations.count > 0 else { return Double.nan }
        let index = Int(round(p * Double(observations.count-1)))
        return observations[index]
    }
    
    // decode and encode taken from "Working with Binary Data in Swift" talk on youtube
    private func decode<T>(data: NSData) -> T {
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T>.size)
        data.getBytes(pointer, length: MemoryLayout<T>.size)
        return pointer.move()
    }
    
    private func encode<T>(arg: T) -> NSData {
        var value = arg
        return withUnsafePointer(to: &value) { p in
            NSData(bytes: p, length: MemoryLayout.size(ofValue: value))
        }
    }
    
    func show(_ d: Double) {
        let x = String(format: "%.4f %.4f %.4f %.4f", d, quantile(0.0), quantile(0.5), quantile(1.0))
        print(x)
    }
}
