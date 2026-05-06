//
//  Debug.swift
//  Pods
//
//  Created by Thanh Le on 28/4/26.
//

class Debug {
    static public func print(_ objects: Any...) {
        let time = getTime()
        #if DEBUG
        Swift.print(time)
        for item in objects {
            Swift.print(item)
        }
        #endif
    }

    static public func print(_ object: Any) {
        let time = getTime()
        #if DEBUG
        Swift.print(time)
        Swift.print(object)
        #endif
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    static func getTime() -> String {
        let currentDate = Date()
        return dateFormatter.string(from: currentDate)
    }

    static public func print(_ object: String) {
        let time = getTime()
        #if DEBUG
        Swift.print("\(time) \(object)")
        #endif
    }

    static public func verbosePrint(_ object: Any) {
        let time = getTime()
        #if DEBUG
        Swift.print(time)
        debugPrint(object)
        #endif
    }
}
