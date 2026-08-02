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
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    static func getTime() -> String {
        var timeValue = timeval()
        // Call the kernel API to fetch high-precision hardware time
        gettimeofday(&timeValue, nil)

        // Date(timeIntervalSince1970:) naturally creates a UTC-based timestamp
        let preciseDate = Date(timeIntervalSince1970: Double(timeValue.tv_sec))
        let microseconds = timeValue.tv_usec

        let dateString = dateFormatter.string(from: preciseDate)
        return String(format: "%@.%06d", dateString, microseconds)
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
