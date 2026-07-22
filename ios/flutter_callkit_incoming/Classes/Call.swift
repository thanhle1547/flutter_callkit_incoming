//
//  Call.swift
//  flutter_callkit_incoming
//
//  Created by Hien Nguyen on 07/10/2021.
//

import Foundation
import AVFoundation
import CallKit

public class Call: NSObject {

    // MARK: - Metadata Properties

    public var uuid: UUID
    public var data: Data
    public var isOutGoing: Bool
    
    public var handle: String?

    // MARK: - State Change Callbacks

    var stateDidChange: (() -> Void)?
    var hasStartedConnectingDidChange: (() -> Void)?
    var hasConnectedDidChange: (() -> Void)?
    var hasEndedDidChange: (() -> Void)?

    // MARK: - Call State Properties

    var connectingDate: Date? {
        didSet {
            stateDidChange?()
            hasStartedConnectingDidChange?()
        }
    }
    
    var connectDate: Date? {
        didSet {
            stateDidChange?()
            hasConnectedDidChange?()
        }
    }
    
    var endDate: Date? {
        didSet {
            stateDidChange?()
            hasEndedDidChange?()
        }
    }
    
    var isOnHold = false {
        didSet {
            stateDidChange?()
        }
    }
    
    var isMuted = false {
        didSet {
            stateDidChange?()
        }
    }

    // MARK: - Derived Properties

    var hasStartedConnecting: Bool {
        get {
            return connectingDate != nil
        }
        set {
            connectingDate = newValue ? Date() : nil
        }
    }
    
    var hasConnected: Bool {
        get {
            return connectDate != nil
        }
        set {
            connectDate = newValue ? Date() : nil
        }
    }
    
    var hasEnded: Bool {
        get {
            return endDate != nil
        }
        set {
            endDate = newValue ? Date() : nil
        }
    }
    
    var duration: TimeInterval {
        guard let connectDate = connectDate else {
            return 0
        }
        return Date().timeIntervalSince(connectDate)
    }

    // MARK: - Initialization

    init(uuid: UUID, data: Data, isOutGoing: Bool = false) {
        self.uuid = uuid
        self.data = data
        self.isOutGoing = isOutGoing
    }

    // MARK: - Actions

    public func notifyConnecting() {
        hasStartedConnecting = true
    }
    
    public func notifyConnected() {
        hasConnected = true
    }
    
    public func notifyEnded() {
        if hasEnded {
            return
        }

        hasEnded = true
    }
}

@objc public class Data: NSObject {
    @objc public var uuid: String
    @objc public var nameCaller: String
    @objc public var phoneNumber: String
    @objc public var appName: String
    @objc public var handle: String
    @objc public var avatar: String
    @objc public var type: Int
    @objc public var normalHandle: Int
    @objc public var duration: Int

    @objc public var isAccepted: Bool
    @objc public var extra: NSDictionary
    @objc public var headers: NSDictionary

    //iOS
    @objc public var iconName: String
    @objc public var handleType: String
    @objc public var supportsVideo: Bool
    @objc public var maximumCallGroups: Int
    @objc public var maximumCallsPerCallGroup: Int
    @nonobjc public var supportedHandleTypes: Set<CXHandle.HandleType>
    @objc public var supportsDTMF: Bool
    @objc public var supportsHolding: Bool
    @objc public var supportsGrouping: Bool
    @objc public var supportsUngrouping: Bool

    /// Determines if the call is recorded in the native Phone app's Recents tab.
    ///
    /// - Note: When using a **Generic Handle** and this is set to `true`,
    ///   the Recents entry may display an encrypted string (e.g., "3f6a2b...")
    ///   instead of the caller's name. This encrypted value is a combination of
    ///   `nameCaller` and `handle` (and `phoneNumber`, if `extra` field exists).
    @objc public var includesCallsInRecents: Bool

    @objc public var ringtonePath: String
    @objc public var configureAudioSession: Bool
    @objc public var audioSessionMode: String
    @objc public var audioSessionActive: Bool
    @objc public var audioSessionPreferredSampleRate: Double
    @objc public var audioSessionPreferredIOBufferDuration: Double
    
    //missedCallNotification
    @objc public var isShowMissedCallNotification: Bool = true
    @objc public var missedNotificationSubtitle: String
    @objc public var missedNotificationCallbackText: String
    @objc public var isShowCallback: Bool = true

    //callingNotification
    @objc public var isShowCallingNotification: Bool = true
    @objc public var callingNotificationSubtitle: String
    @objc public var callingNotificationHangupText: String
    @objc public var isShowHangup: Bool = true

    @objc public var didReportCallEndReasonAsFailed: Bool = false
    
    @objc public init(id: String, nameCaller: String, phoneNumber: String, handle: String, type: Int) {
        self.uuid = id
        self.nameCaller = nameCaller
        self.phoneNumber = phoneNumber
        self.appName = "Callkit"
        self.avatar = ""
        self.handle = handle
        self.type = type
        self.normalHandle = 0
        self.duration = 30000
        self.isAccepted = false

        self.extra = [:]
        self.headers = [:]

        self.iconName = "CallKitLogo"
        self.handleType = ""
        self.supportsVideo = true
        self.maximumCallGroups = 2
        self.maximumCallsPerCallGroup = 1
        self.supportedHandleTypes = [
            CXHandle.HandleType.generic,
            CXHandle.HandleType.emailAddress,
            CXHandle.HandleType.phoneNumber
        ]
        self.supportsDTMF = true
        self.supportsHolding = true
        self.supportsGrouping = true
        self.supportsUngrouping = true
        self.includesCallsInRecents = true
        self.ringtonePath = ""
        self.configureAudioSession = true
        self.audioSessionMode = ""
        self.audioSessionActive = true
        self.audioSessionPreferredSampleRate = 44100.0
        self.audioSessionPreferredIOBufferDuration = 0.005

        self.isShowMissedCallNotification = true
        self.missedNotificationSubtitle = "Missed Call"
        self.missedNotificationCallbackText = "Call back"
        self.isShowCallback = true

        self.isShowCallingNotification = true
        self.callingNotificationSubtitle = "Calling"
        self.callingNotificationHangupText = "Hang up"
        self.isShowHangup = true
    }
    
    @objc public convenience init(args: NSDictionary) {
        var argsConvert = [String: Any?]()
        for (key, value) in args {
            argsConvert[key as! String] = value
        }
        self.init(args: argsConvert)
    }
    
    public init(args: [String: Any?]) {
        self.uuid = args["id"] as? String ?? ""
        self.nameCaller = args["nameCaller"] as? String ?? ""
        self.phoneNumber = args["phoneNumber"] as? String ?? ""
        self.appName = args["appName"] as? String ?? "Callkit"
        self.handle = args["handle"] as? String ?? ""
        self.avatar = args["avatar"] as? String ?? ""
        self.type = args["type"] as? Int ?? 0
        self.duration = args["duration"] as? Int ?? 30000
        self.isAccepted = args["isAccepted"] as? Bool ?? false
        self.extra = args["extra"] as? NSDictionary ?? [:]
        self.headers = args["headers"] as? NSDictionary ?? [:]


        if let ios = args["ios"] as? [String: Any] {
            self.iconName = ios["iconName"] as? String ?? "CallKitLogo"
            self.handleType = ios["handleType"] as? String ?? ""
            self.normalHandle = ios["normalHandle"] as? Int ?? 0
            self.supportsVideo = ios["supportsVideo"] as? Bool ?? true
            self.maximumCallGroups = ios["maximumCallGroups"] as? Int ?? 2
            self.maximumCallsPerCallGroup = ios["maximumCallsPerCallGroup"] as? Int ?? 1
            self.supportedHandleTypes = Set(
                (ios["supportedHandleTypes"] as? Set<Int>)?.compactMap { CXHandle.HandleType(rawValue: $0) }
                ?? [
                    CXHandle.HandleType.generic,
                    CXHandle.HandleType.emailAddress,
                    CXHandle.HandleType.phoneNumber
                ]
            )
            self.supportsDTMF = ios["supportsDTMF"] as? Bool ?? true
            self.supportsHolding = ios["supportsHolding"] as? Bool ?? true
            self.supportsGrouping = ios["supportsGrouping"] as? Bool ?? true
            self.supportsUngrouping = ios["supportsUngrouping"] as? Bool ?? true
            self.includesCallsInRecents = ios["includesCallsInRecents"] as? Bool ?? true
            self.ringtonePath = ios["ringtonePath"] as? String ?? ""
            self.configureAudioSession = ios["configureAudioSession"] as? Bool ?? true
            self.audioSessionMode = ios["audioSessionMode"] as? String ?? ""
            self.audioSessionActive = ios["audioSessionActive"] as? Bool ?? true
            self.audioSessionPreferredSampleRate = ios["audioSessionPreferredSampleRate"] as? Double ?? 44100.0
            self.audioSessionPreferredIOBufferDuration = ios["audioSessionPreferredIOBufferDuration"] as? Double ?? 0.005
        }else {
            self.iconName = args["iconName"] as? String ?? "CallKitLogo"
            self.handleType = args["handleType"] as? String ?? ""
            self.normalHandle = args["normalHandle"] as? Int ?? 0
            self.supportsVideo = args["supportsVideo"] as? Bool ?? true
            self.maximumCallGroups = args["maximumCallGroups"] as? Int ?? 2
            self.maximumCallsPerCallGroup =  args["maximumCallsPerCallGroup"] as? Int ?? 1
            self.supportedHandleTypes = Set(
                (args["supportedHandleTypes"] as? Set<Int>)?.compactMap { CXHandle.HandleType(rawValue: $0) }
                ?? [
                    CXHandle.HandleType.generic,
                    CXHandle.HandleType.emailAddress,
                    CXHandle.HandleType.phoneNumber
                ]
            )
            self.supportsDTMF = args["supportsDTMF"] as? Bool ?? true
            self.supportsHolding = args["supportsHolding"] as? Bool ?? true
            self.supportsGrouping = args["supportsGrouping"] as? Bool ?? true
            self.supportsUngrouping = args["supportsUngrouping"] as? Bool ?? true
            self.includesCallsInRecents = args["includesCallsInRecents"] as? Bool ?? true
            self.ringtonePath = args["ringtonePath"] as? String ?? ""
            self.configureAudioSession = args["configureAudioSession"] as? Bool ?? true
            self.audioSessionMode = args["audioSessionMode"] as? String ?? ""
            self.audioSessionActive = args["audioSessionActive"] as? Bool ?? true
            self.audioSessionPreferredSampleRate = args["audioSessionPreferredSampleRate"] as? Double ?? 44100.0
            self.audioSessionPreferredIOBufferDuration = args["audioSessionPreferredIOBufferDuration"] as? Double ?? 0.005
        }
        if let missedCallNotification = args["missedCallNotification"] as? [String: Any] {
            self.isShowMissedCallNotification = missedCallNotification["showNotification"] as? Bool ?? true
            self.missedNotificationSubtitle = missedCallNotification["subtitle"] as? String ?? "Missed Call"
            self.missedNotificationCallbackText = missedCallNotification["callbackText"] as? String ?? "Call back"
            self.isShowCallback = missedCallNotification["isShowCallback"] as? Bool ?? true
        }else {
            self.isShowMissedCallNotification = true
            self.missedNotificationSubtitle = "Missed Call"
            self.missedNotificationCallbackText = "Call back"
            self.isShowCallback = true
        }

        if let callingNotification = args["callingNotification"] as? [String: Any] {
            self.isShowCallingNotification = callingNotification["showNotification"] as? Bool ?? true
            self.callingNotificationSubtitle = callingNotification["subtitle"] as? String ?? "Calling"
            self.callingNotificationHangupText = callingNotification["callbackText"] as? String ?? "Hang up"
            self.isShowHangup = callingNotification["isShowCallback"] as? Bool ?? true
        }else {
            self.isShowCallingNotification = true
            self.callingNotificationSubtitle = "Calling"
            self.callingNotificationHangupText = "Hang up"
            self.isShowHangup = true
        }
    }
    
    func checkIsDataForConfigurationChange(_ configuration: CXProviderConfiguration?) -> Bool {
        if let configuration = configuration {
            if #available(iOS 11.0, *) {
                if (includesCallsInRecents != configuration.includesCallsInRecents) {
                    return true
                }
            }

            return supportsVideo != configuration.supportsVideo
                || maximumCallGroups != configuration.maximumCallGroups
                || maximumCallsPerCallGroup != configuration.maximumCallsPerCallGroup
                || supportedHandleTypes.count != configuration.supportedHandleTypes.count
                || supportedHandleTypes.intersection(configuration.supportedHandleTypes).isEmpty == false
                || ringtonePath != configuration.ringtoneSound
        } else {
            return false
        }
    }
    
    open func toJSON() -> [String: Any] {
        let missedCallNotification: [String : Any] = [
            "showNotification": isShowMissedCallNotification,
            "subtitle": missedNotificationSubtitle,
            "callbackText": missedNotificationCallbackText,
            "isShowCallback": isShowCallback
        ]
        let callingNotification: [String : Any] = [
            "showNotification": isShowCallingNotification,
            "subtitle": callingNotificationSubtitle,
            "callbackText": callingNotificationHangupText,
            "isShowCallback": isShowHangup,
            "didReportCallEndReasonAsFailed": didReportCallEndReasonAsFailed,
        ]
        let ios: [String : Any] = [
            "iconName": iconName,
            "handleType": handleType,
            "normalHandle": normalHandle,
            "supportsVideo": supportsVideo,
            "maximumCallGroups": maximumCallGroups,
            "maximumCallsPerCallGroup": maximumCallsPerCallGroup,
            "supportedHandleTypes": supportedHandleTypes.map { $0.rawValue },
            "supportsDTMF": supportsDTMF,
            "supportsHolding": supportsHolding,
            "supportsGrouping": supportsGrouping,
            "supportsUngrouping": supportsUngrouping,
            "includesCallsInRecents": includesCallsInRecents,
            "ringtonePath": ringtonePath,
            "configureAudioSession": configureAudioSession,
            "audioSessionMode": audioSessionMode,
            "audioSessionActive": audioSessionActive,
            "audioSessionPreferredSampleRate": audioSessionPreferredSampleRate,
            "audioSessionPreferredIOBufferDuration": audioSessionPreferredIOBufferDuration
        ]
        let map: [String : Any] = [
            "uuid": uuid,
            "id": uuid,
            "nameCaller": nameCaller,
            "phoneNumber": phoneNumber,
            "appName": appName,
            "handle": handle,
            "avatar": avatar,
            "type": type,
            "duration": duration,
            "isAccepted": isAccepted,
            "extra": extra,
            "headers": headers,
            "ios": ios,
            "missedCallNotification": missedCallNotification,
            "callingNotification": callingNotification
        ]
        return map
    }

    open func getEncryptHandle() -> String {
        print("Encrypt handle")

        if (normalHandle > 0) {
            return handle
        }
        do {
            var map: [String: Any] = [:]

            map["nameCaller"] = nameCaller
            map["phoneNumber"] = phoneNumber
            map["handle"] = handle
            
            let mapExtras = extra as? [String: Any]
            
            if (mapExtras == nil) {
                print("error casting dictionary to [String: Any]")
                return String(format: "{\"nameCaller\":\"%@\", \"handle\":\"%@\"}", nameCaller, handle).encryptHandle()
            }
            
            for (key, value) in mapExtras! {
                map[key] = value
            }
            
            let mapData = try JSONSerialization.data(withJSONObject: map, options: .prettyPrinted)

            let mapString: String = String(data: mapData, encoding: .utf8) ?? ""

            return mapString.encryptHandle()
        } catch {
            print("error encrypting call data")
            return String(format: "{\"nameCaller\":\"%@\", \"handle\":\"%@\"}", nameCaller, handle).encryptHandle()
        }
       
    }
    
    
}
