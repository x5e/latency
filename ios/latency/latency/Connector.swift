import Foundation
import CoreLocation
import NotificationCenter

class Connector: WebSocketDelegate {
    var soc: WebSocket? = nil
    var observations: [Double] = []
    var sorted: [Double] = []
    var trail: Int?
    var active = false
    var state = "Created"
    var server = "latency.x5e.com"
    var remoteName: String?
    var updates = 0
    //var hitId: Int64 = 9007199254740992
    var oHitId: Int64?
    
    func stop() {
        soc?.disconnect()
    }
    
    func distances(_ loc: CLLocation) -> TopMap {
        // print(loc)
        var out = TopMap()
        out["us-west-1"] = loc.distance(from: CLLocation(latitude: 37, longitude: -122))/1e3
        out["us-east-1"] = loc.distance(from: CLLocation(latitude: 37, longitude: -78))/1e3
        out["us-east-2"] = loc.distance(from: CLLocation(latitude: 40, longitude: -83))/1e3
        out["us-west-2"] = loc.distance(from: CLLocation(latitude: 46, longitude: -122))/1e3
        out["nearby-ny"] = loc.distance(from: CLLocation(latitude: 41, longitude: -74))/1e3
        //print(out)
        return out
    }
    
    func knock(from: CLLocation?) {

        // largely copied from http://stackoverflow.com/questions/26364914/http-request-in-swift-with-post-method
        let target = "https://" + server + "/latency/xhr/knock"
        var payload = deviceInfo()
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            payload["app_version"] = version
        }
        if let loc = from {
            payload["latitude"] = loc.coordinate.latitude
            payload["longitude"] = loc.coordinate.longitude
            payload["accuracy"] = loc.horizontalAccuracy
            payload["loc_ts"] = String(describing: loc.timestamp)
            payload["distances"] = distances(loc)
        }
        payload["server"] = server
        // print(payload)
        update("Knocking...")
        post(
            url: target,
            map: payload,
            cb: {self.onAnswer($0)},
            onError: {self.update("Offline"); print($0)}
        )
    }
    
    func onAnswer(_ thing: Any) {
        if let map = thing as? NSDictionary {
            oHitId = ((map["hit_id"] as? NSNumber) as? Int64)
            server = (map["server"] as? String) ?? server
            remoteName = (map["name"] as? String)
        }
        connect()
        //guard let hitId = Int64(responseString) else {return onError("not a hitId \(responseString)")}
    }
    
    func connect() {
        // print(oHitId ?? "no hitId")
        // print(server)
        guard let hitId = oHitId else { return update("No hitId?") }
        update("Connecting...")
        let target = "wss://\(server)/latency/websocket?\(hitId)"
        soc = WebSocket(url: URL(string: target)!)
        soc!.delegate = self
        soc!.connect()
    }
    
    func register() {
        _ = NotificationCenter.default.addObserver(
            self,
            selector: #selector(onBg),
            name: Notification.Name.UIApplicationWillResignActive,
            object: nil)
        
    }
    
    @objc func onBg() {
        active = false
        update("Lost Focus")
        soc?.disconnect(forceTimeout: 0.00001)
    }
    
    func websocketDidConnect(socket: WebSocket) {
        active = true
        //print("websocket is connected")
        register()
        update("Connected")
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        active = false
        print("websocket is disconnected: \(error?.localizedDescription)")
        update("Done")
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        if active {
            socket.write(string: text)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        //print("got some data: \(data.count)")
        let d:Double = decode(data: data as NSData)
        observations.append(d)
        sorted.append(d)
        sorted.sort()
        // show(d)
        update()
    }
    
    func quantile(_ p: Double) -> Double {
        guard sorted.count > 0 else { return Double.nan }
        let index = Int(round(p * Double(sorted.count-1)))
        return sorted[index]
    }
    
    func show(_ d: Double) {
        let x = String(format: "%.4f %.4f %.4f %.4f", d, quantile(0.0), quantile(0.5), quantile(1.0))
        print(x)
    }
    
    func update(_ ostatus: String? = nil) {
        updates += 1
        state = ostatus ?? state
        let x = Notification(name:NSNotification.Name(rawValue: "thump"), object: nil, userInfo: [:])
        NotificationCenter.default.post(x)
    }
}
