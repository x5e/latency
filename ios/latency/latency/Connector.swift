import Foundation

class Connector: WebSocketDelegate {
    var soc: WebSocket? = nil
    var observations: [Double] = []
    let server: String
    var trail: Int?
    
    init(server: String = "latency.x5e.qa", trail: Int? = nil) {
        self.server = server
        self.trail = trail
    }
    
    func doHit() {
        // largely copied from http://stackoverflow.com/questions/26364914/http-request-in-swift-with-post-method
        let target = "https://" + server + "/xhr/hit"
        var request = URLRequest(url: URL(string: target)!)
        request.httpMethod = "POST"
        request.httpBody = "{}".data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {return onError("error=\(error)")}
            guard let httpStatus = response as? HTTPURLResponse else {return onError("wtf")}
            guard httpStatus.statusCode == 200 else { return onError("statusCode is \(httpStatus.statusCode)")}
            guard let responseString = String(data: data, encoding: .utf8) else {return onError("no responseString?")}
            guard let hitId = Int(responseString) else {return onError("not a hitId \(responseString)")}
            self.connect(hitId)
        }
        task.resume()
    }

    func connect(_ hitId: Int = 9007199254740992) {
        let target = "wss://\(server)/websocket?\(hitId)"
        soc = WebSocket(url: URL(string: target)!)
        soc!.delegate = self
        soc!.connect()
    }
    
    func websocketDidConnect(socket: WebSocket) { print("websocket is connected") }
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) { print("websocket is disconnected: \(error?.localizedDescription)") }
    func websocketDidReceiveMessage(socket: WebSocket, text: String) { socket.write(string: text) }
    
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
    
    func show(_ d: Double) {
        let x = String(format: "%.4f %.4f %.4f %.4f", d, quantile(0.0), quantile(0.5), quantile(1.0))
        print(x)
    }
}
