import Foundation

// decode and encode taken from "Working with Binary Data in Swift" talk on youtube
func decode<T>(data: NSData) -> T {
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T>.size)
    data.getBytes(pointer, length: MemoryLayout<T>.size)
    return pointer.move()
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
