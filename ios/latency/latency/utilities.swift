import Foundation
import UIKit

// decode and encode taken from "Working with Binary Data in Swift" talk on youtube
func decode<T>(data: NSData) -> T {
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T>.size)
    data.getBytes(pointer, length: MemoryLayout<T>.size)
    return pointer.move()
}

func toHuman(_ d: Double) -> String {
    var out = ""
    if d < 1 {
        out = String(format: "%.1f", d * 1000)
        while out.characters.count < 6 {
            out = " " + out
        }
        out += " millis"
    }
    if d >= 1 {
        out = String(format: "%.1f", d)
        while out.characters.count < 6 {
            out = " " + out
        }
        out += " second"
    }
    return out
}

func encode<T>(arg: T) -> NSData {
    var value = arg
    return withUnsafePointer(to: &value) { p in
        NSData(bytes: p, length: MemoryLayout.size(ofValue: value))
    }
}

func onError(_ msg: String? = nil) {
    let msg1 = msg ?? "someting went wrong"
    print(msg1)
}

public extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        switch identifier {
        case "iPod5,1":
            return "iPod Touch 5"
        case "iPod7,1":
            return "iPod Touch 6"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":
            return "iPhone 4"
        case "iPhone4,1":
            return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":
            return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":
            return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":
            return "iPhone 5s"
        case "iPhone7,2":
            return "iPhone 6"
        case "iPhone7,1":
            return "iPhone 6 Plus"
        case "iPhone8,1":
            return "iPhone 6s"
        case "iPhone8,2":
            return "iPhone 6s Plus"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":
            return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":
            return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":
            return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":
            return "iPad Air"
        case "iPad5,3", "iPad5,4":
            return "iPad Air 2"
        case "iPad2,5", "iPad2,6", "iPad2,7":
            return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":
            return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":
            return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":
            return "iPad Mini 4"
        case "iPad6,7", "iPad6,8":
            return "iPad Pro"
        case "AppleTV5,3":
            return "Apple TV"
        case "i386", "x86_64":
            return "Simulator"
        default:
            return identifier
        }
    }
}

func deviceInfo() -> [String: Any] {
    var out = [String: Any]()
    let uiDevice = UIDevice()
    out["name"] = uiDevice.name
    out["systemName"] = uiDevice.systemName
    out["model"] = uiDevice.model
    out["localizedModel"] = uiDevice.localizedModel
    out["userInterfaceIdiom"] = uiDevice.userInterfaceIdiom.rawValue
    out["identifierForVendor"] = uiDevice.identifierForVendor?.uuidString
    out["batteryLevel"] = uiDevice.batteryLevel
    out["batteryState"] = uiDevice.batteryState.rawValue
    out["systemVersion"] = UIDevice.current.systemVersion
    out["systemName"] = UIDevice.current.systemName
    out["modelName"] = uiDevice.modelName
    return out
}

typealias Json = String

func toJson(thing: Any) -> Json {
    if let i = thing as? Int {return String(i)}
    if let s = thing as? String { return "\"\(s)\"" }
    if let f = thing as? Float { return "\(f)" }
    return "\(thing)"
}

func toJson(map: [String: Any]) -> Json {
    var out = "{"
    var first = true
    for (k,v) in map {
        if first { first = false }
        else { out += ",\n" }
        let vj = toJson(thing: v)
        let kj = toJson(thing: k)
        out += "\(kj):\(vj)"
    }
    out += "}"
    return out
}
