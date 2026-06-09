import Flutter
import UIKit
import CallKit
import AVFoundation
import UserNotifications

@available(iOS 10.0, *)
public class SwiftFlutterCallkitIncomingPlugin: NSObject, FlutterPlugin, CXProviderDelegate {
    
    static let ACTION_DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP = "com.hiennv.flutter_callkit_incoming.DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP"
    
    static let ACTION_CALL_INCOMING = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_INCOMING"
    static let ACTION_CALL_START = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_START"
    static let ACTION_CALL_ACCEPT = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT"
    static let ACTION_CALL_DECLINE = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_DECLINE"
    static let ACTION_CALL_ENDED = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ENDED"
    static let ACTION_CALL_TIMEOUT = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TIMEOUT"
    static let ACTION_CALL_FAILED = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_FAILED"
    static let ACTION_CALL_CALLBACK = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_CALLBACK"
    static let ACTION_CALL_CUSTOM = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_CUSTOM"
    static let ACTION_CALL_CONNECTED = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_CONNECTED"
    
    static let ACTION_CALL_TOGGLE_HOLD = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_HOLD"
    static let ACTION_CALL_TOGGLE_MUTE = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_MUTE"
    static let ACTION_CALL_TOGGLE_SPEAKER = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_SPEAKER"
    static let ACTION_CALL_TOGGLE_DMTF = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_DMTF"
    static let ACTION_CALL_TOGGLE_GROUP = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_GROUP"
    static let ACTION_CALL_TOGGLE_AUDIO_SESSION = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_AUDIO_SESSION"
    
    static let PUSH_KIT_INCOMING_CALL = "com.hiennv.flutter_callkit_incoming.PUSH_KIT_INCOMING_CALL"
    
    @objc public private(set) static var sharedInstance: SwiftFlutterCallkitIncomingPlugin!
    @objc public static var onAudioSessionConfigurationError: ((NSError?) -> Void)?
    
    private var streamHandlers: WeakArray<EventCallbackHandler> = WeakArray([])
    
    private var callManager: CallManager
    
    private var sharedProvider: CXProvider? = nil
    
    private var audioController: AudioController?

    private(set) var outgoingCall : Call?
    private(set) var answerCall : Call?
    
    private var data: Data?
    private var outgoingCallData: Data?
    private var answerCallData: Data?
    private var isFromPushKit: Bool = false
    private var silenceEvents: Bool = false
    private let devicePushTokenVoIP = "DevicePushTokenVoIP"

    public var uuid: String? {
        get {
            data?.uuid
        }
    }
    
    // Weak reference to prevent memory leaks
    public weak var callDelegate: CallkitIncomingCallDelegate?

    public static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            return true
        } else {
            return false
        }
        #endif
    }
    
    private func sendEvent(_ event: String, _ body: [String : Any?]?) {
        if silenceEvents {
            Debug.print(event, " silenced")
            return
        } else {
            Debug.print(event)
            streamHandlers.reap().forEach { handler in
                handler?.send(event, body ?? [:])
            }
        }
        
    }
    
    @objc public func sendEventCustom(_ event: String, body: NSDictionary?) {
        streamHandlers.reap().forEach { handler in
            handler?.send(event, body ?? [:])
        }
    }
    
    public static func sharePluginWithRegister(with registrar: FlutterPluginRegistrar) {
        if(sharedInstance == nil){
            sharedInstance = SwiftFlutterCallkitIncomingPlugin(messenger: registrar.messenger())
        }
        sharedInstance.shareHandlers(with: registrar)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        sharePluginWithRegister(with: registrar)
    }
    
    private static func createMethodChannel(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
        return FlutterMethodChannel(name: "flutter_callkit_incoming", binaryMessenger: messenger)
    }
    
    private static func createEventChannel(messenger: FlutterBinaryMessenger) -> FlutterEventChannel {
        return FlutterEventChannel(name: "flutter_callkit_incoming_events", binaryMessenger: messenger)
    }
    
    public init(messenger: FlutterBinaryMessenger) {
        callManager = CallManager()
    }
    
    private func shareHandlers(with registrar: FlutterPluginRegistrar) {
        registrar.addMethodCallDelegate(self, channel: Self.createMethodChannel(messenger: registrar.messenger()))
        let eventsHandler = EventCallbackHandler()
        self.streamHandlers.append(eventsHandler)
        Self.createEventChannel(messenger: registrar.messenger()).setStreamHandler(eventsHandler)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showCallkitIncoming":
            guard let args = call.arguments else {
                result(
                    FlutterError(
                        code: "missing_arguments",
                        message: "Missing arguments",
                        details: nil
                    )
                )
                return
            }

            if let getArgs = args as? [String: Any] {
                let data = Data(args: getArgs)

                self.data = data
                self.answerCallData = data

                showCallkitIncoming(
                    data,
                    fromPushKit: false,
                    completion: { error in
                        if let error = error {
                            Debug.print("FlutterMethodCall.showCallkitIncoming", "error \(error) |> \(String(describing: error.localizedFailureReason))")

                            result(
                                FlutterError(
                                    code: String(error.code),
                                    message: error.localizedDescription,
                                    details: error.localizedFailureReason
                                )
                            )

                            return
                        }

                        result(true)
                    }
                )
            } else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }
            break
        case "showMissCallNotification":
            guard let args = call.arguments else {
                result(
                    FlutterError(
                        code: "missing_arguments",
                        message: "Missing arguments",
                        details: nil
                    )
                )
                return
            }
            if let getArgs = args as? [String: Any] {
                let data = Data(args: getArgs)

                self.data = data

                self.showMissedCallNotification(data)

                result(true)
            } else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }
            break
        case "startCall":
            guard let args = call.arguments else {
                result(
                    FlutterError(
                        code: "missing_arguments",
                        message: "Missing arguments",
                        details: nil
                    )
                )
                return
            }
            if let getArgs = args as? [String: Any] {
                let data = Data(args: getArgs)

                self.data = data

                self.startCall(data, fromPushKit: false)

                result(true)
            } else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }
            break
        case "updateCallerName":
            guard let args = call.arguments as? [String: Any],
                  let callId = args["id"] as? String,
                  let nameCaller = args["nameCaller"] as? String else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
                return
            }
            
            self.updateCallerName(callId, name: nameCaller)
            result(true)
            break
        case "endCall":
            guard let args = call.arguments else {
                result(
                    FlutterError(
                        code: "missing_arguments",
                        message: "Missing arguments",
                        details: nil
                    )
                )
                return
            }
            
            var errorDetails: String? = nil

            if (self.isFromPushKit) {
                errorDetails = "from PushKit"
            } else {
                if let getArgs = args as? [String: Any] {
                    let id = getArgs["id"] as? String
                    if let id = id {
                        self.data?.uuid = id
                    }
                }
            }
            
            if let data = data {
                do {
                    try self.endCall(data)
                    result(true)
                } catch InvalidError.uuid {
                    result(
                        FlutterError(
                            code: "invalid_error",
                            message: "Invalid UUID",
                            details: errorDetails
                        )
                    )
                } catch {
                    // exhaustive
                    Debug.print("Unexpected error: \(error)")
                    result(
                        FlutterError(
                            code: "unknown_error",
                            message: String(describing: error),
                            details: errorDetails
                        )
                    )
                }
            } else {
                result(
                    FlutterError(
                        code: "no_data",
                        message: "No data",
                        details: errorDetails
                    )
                )
                return
            }

            break
        case "muteCall":
            guard let args = call.arguments as? [String: Any],
                  let callId = args["id"] as? String,
                  let isMuted = args["isMuted"] as? Bool else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
                return
            }
            
            self.muteCall(callId, isMuted: isMuted)
            result(true)
            break
        case "isMuted":
            guard let args = call.arguments as? [String: Any],
                  let callId = args["id"] as? String else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
                return
            }
            guard let callUUID = UUID(uuidString: callId),
                  let call = self.callManager.callWithUUID(uuid: callUUID) else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid UUID",
                        details: nil
                    )
                )
                return
            }
            result(call.isMuted)
            break
        case "holdCall":
            guard let args = call.arguments as? [String: Any] ,
                  let callId = args["id"] as? String,
                  let onHold = args["isOnHold"] as? Bool else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
                return
            }
            self.holdCall(callId, onHold: onHold)
            result(true)
            break
        case "callConnected":
            guard let args = call.arguments else {
                result(
                    FlutterError(
                        code: "missing_arguments",
                        message: "Missing arguments",
                        details: nil
                    )
                )
                return
            }
            if (self.isFromPushKit) {
                self.connectedCall(self.data!)
            } else {
                if let getArgs = args as? [String: Any] {
                    let id = getArgs["id"] as? String
                    if let id = id {
                        self.data?.uuid = id
                    }

                    self.connectedCall(self.data!)
                } else if let data = data {
                    self.connectedCall(data)
                }
            }
            result(true)
            break
        case "activeCalls":
            result(self.callManager.activeCalls())
            break;
        case "endAllCalls":
            self.callManager.endCallAlls()
            result(true)
            break
        case "reportCallEnd":
            guard let args = call.arguments as? [String: Any],
                  let uuid = args["uuid"] as? String? else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
                return
            }

            result(
                self.reportCallEnd(uuid)
            )
            break;
        case "getDevicePushTokenVoIP":
            result(self.getDevicePushTokenVoIP())
            break;
        case "isSandboxEnvironment":
            result(self.isSandboxEnvironment())
            break;
        case "silenceEvents":
            guard let silence = call.arguments as? Bool else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
                return
            }
            
            self.silenceEvents = silence
            result(true)
            break;
        case "requestNotificationPermission":
            guard let args = call.arguments else {
                result(
                    FlutterError(
                        code: "missing_arguments",
                        message: "Missing arguments",
                        details: nil
                    )
                )
                return
            }
            if let getArgs = args as? [String: Any] {
                self.requestNotificationPermission(getArgs)
                result(true)
            } else {
                result(
                    FlutterError(
                        code: "invalid_error",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }
            break
         case "requestFullIntentPermission": 
            result(true)
            break
         case "canUseFullScreenIntent": 
            result(true)
            break
         case "isFullIntentPermissionInManifest":
            result(true)
            break
        case "hideCallkitIncoming":
            result(true)
            break
        case "endNativeSubsystemOnly":
            result(true)
            break
        case "setAudioRoute":
            result(true)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    @objc public func setDevicePushTokenVoIP(_ deviceToken: String) {
        UserDefaults.standard.set(deviceToken, forKey: devicePushTokenVoIP)
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP, ["deviceTokenVoIP":deviceToken])
    }
    
    @objc public func getDevicePushTokenVoIP() -> String {
        return UserDefaults.standard.string(forKey: devicePushTokenVoIP) ?? ""
    }

    /**
     * Returns true if the app is in a development state.
     *
     * This uses a two-layered detection:
     * 1. Build-time: Uses the DEBUG flag to identify a Debug configuration.
     * 2. Runtime: Uses the sysctl P_TRACED check to detect an active debugger attachment.
     *
     * @warning This function will return FALSE on production App Store builds.
     * On iOS, debuggers cannot be attached to App Store-distributed binaries
     * due to system-level security restrictions (get-task-allow=false).
     */
    @objc public func isSandboxEnvironment() -> Bool {
        #if DEBUG
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

        if result == 0 {
            return (info.kp_proc.p_flag & P_TRACED) != 0
        }
        return false
        #else
        return false
        #endif
    }

    @objc public func getAcceptedCall() -> Data? {
        NSLog("Call data ids \(String(describing: data?.uuid)) \(String(describing: answerCall?.uuid.uuidString))")
        if data?.uuid.lowercased() == answerCall?.uuid.uuidString.lowercased() {
            return data
        }
        return nil
    }
    
    /// Use CXProvider to report the incoming call to the system
    /// - Parameters:
    ///   - completion: A closure that is executed once the call is allowed or disallowed by the system
    @objc public func showCallkitIncoming(_ data: Data, fromPushKit: Bool, completion: ((NSError?) -> Void)?) {
        self.isFromPushKit = fromPushKit
        if(fromPushKit){
            self.data = data
            self.answerCallData = data
        }

        if(data.isShowMissedCallNotification){
            CallkitNotificationManager.shared.addNotificationCategory(data.missedNotificationCallbackText)
        }
        
        let nativeHandle: CXHandle
        if (data.phoneNumber.isEmpty) {
            nativeHandle = CXHandle(type: .generic, value: data.getEncryptHandle())
        } else {
            nativeHandle = CXHandle(type: .phoneNumber, value: data.phoneNumber)
        }
        
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = nativeHandle
        callUpdate.supportsDTMF = data.supportsDTMF
        callUpdate.supportsHolding = data.supportsHolding
        callUpdate.supportsGrouping = data.supportsGrouping
        callUpdate.supportsUngrouping = data.supportsUngrouping
        callUpdate.hasVideo = data.type > 0 ? true : false
        callUpdate.localizedCallerName = data.nameCaller
        
        initCallkitProvider(data)
        audioController?.setupAudioSessionObservers()
        
        let uuid = UUID(uuidString: data.uuid)

        if (fromPushKit) {
            self.sendEvent(
                SwiftFlutterCallkitIncomingPlugin.PUSH_KIT_INCOMING_CALL,
                data.toJSON()
            )
        }

        self.sharedProvider?.reportNewIncomingCall(with: uuid!, update: callUpdate) { error in
            /*
             Only add an incoming call to an app's list of calls if it's allowed, i.e., there is no error.
             Calls may be denied for various legitimate reasons. See CXErrorCodeIncomingCallError.
             */
            if (error == nil) {
                let call = Call(uuid: uuid!, data: data)
                call.handle = data.handle

                self.callManager.addCall(call)

                self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_INCOMING, data.toJSON())

                self.endCallNotExist(data)
            }

            completion?(error as NSError?)
        }
    }

    @objc public func showCallkitIncomingWithDelay(
        _ data: Data,
        fromPushKit: Bool,
        after delay: TimeInterval,
        shouldQueue: Bool,
        onWillQueue: (() -> Void)? = nil,
        executionPredicate: ((_ inQueue: Bool) -> Bool)? = nil,
        completion: ((NSError?) -> Void)?,
    ) {
        let performAction: (Bool) -> Void = { inQueue in
            if let shouldProceed = executionPredicate?(inQueue), !shouldProceed {
                return
            }
            self.showCallkitIncoming(data, fromPushKit: fromPushKit, completion: completion)
        }

        if shouldQueue && delay > 0 {
            onWillQueue?()
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                performAction(true)
            }
        } else {
            performAction(false) // Executing immediately
        }
    }

    /// Creates a new outgoing call with the specified details.
    @objc public func startCall(_ data: Data, fromPushKit: Bool) {
        self.isFromPushKit = fromPushKit
        if(fromPushKit){
            self.data = data
        }
        self.outgoingCallData = data
        initCallkitProvider(data)
        audioController?.setupAudioSessionObservers()
        self.callManager.startCall(data)
    }
    
    @objc public func updateCallerName(_ callId: String, name: String) {
        guard let callId = UUID(uuidString: callId) else {
            return
        }
        self.callManager.updateCallerName(callId, name)
    }
    
    @objc public func muteCall(_ callId: String, isMuted: Bool) {
        guard let callId = UUID(uuidString: callId),
              let call = self.callManager.callWithUUID(uuid: callId) else {
            return
        }
        if call.isMuted == isMuted {
            self.sendMuteEvent(callId.uuidString, isMuted)
        } else {
            self.callManager.muteCall(call: call, isMuted: isMuted)
        }
    }
    
    @objc public func holdCall(_ callId: String, onHold: Bool) {
        guard let callId = UUID(uuidString: callId),
              let call = self.callManager.callWithUUID(uuid: callId) else {
            return
        }

        if call.isOnHold == onHold {
            self.sendMuteEvent(callId.uuidString,  onHold)
        } else {
            self.callManager.holdCall(call: call, onHold: onHold)
        }
    }
    
    @objc public func endCall(_ data: Data, completion: ((Bool) -> Void)? = nil) throws {
        var uuid: UUID? = nil

        if (self.isFromPushKit) {
            uuid = UUID(uuidString: self.data?.uuid ?? data.uuid)
        } else {
            uuid = UUID(uuidString: data.uuid)
        }

        guard uuid != nil else {
            deactivateAudioSession()
            throw InvalidError.uuid
        }

        if self.callManager.didCallWithUuidEnd(uuid!) {
            return
        }

        let call = Call(uuid: uuid!, data: data)
        
        if (self.isFromPushKit) {
            self.isFromPushKit = false
            self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, data.toJSON())
        }

        self.callManager.endCall(call: call, completion: completion)
        
        deactivateAudioSession()
    }
    
    /// Requesting a `CXEndCallAction` transaction to end a call can fail for several reasons:
    ///
    /// - The `UUID` is invalid or not found.
    /// - The call has already ended or is in a state that cannot be transitioned.
    /// - System constraints (e.g., restricted permissions) prevent the transaction.
    @objc public func endACallOf(_ call: Call) throws {
        if (self.isFromPushKit) {
            self.isFromPushKit = false
            self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, call.data.toJSON())
        }

        self.callManager.endCall(call: call)
        
        // Error Domain=NSOSStatusErrorDomain Code=-12988 "Session deactivation failed" UserInfo={NSLocalizedDescription=Session deactivation failed}
        // deactivateAudioSession()
    }

    @objc public func connectedCall(_ data: Data) {
        var call: Call? = nil
        if(self.isFromPushKit){
            call = Call(uuid: UUID(uuidString: self.data!.uuid)!, data: data)
            self.isFromPushKit = false
        }else {
            call = Call(uuid: UUID(uuidString: data.uuid)!, data: data)
        }
        self.callManager.connectedCall(call: call!)
    }
    
    @objc public func activeCalls() -> [[String: Any]] {
        return self.callManager.activeCalls()
    }

    @objc public func allCalls() -> [Call] {
        return self.callManager.calls
    }
    
    @objc public func endAllCalls() {
        self.isFromPushKit = false
        self.callManager.endCallAlls()
    }
    
    func configureAudioSession() {
        if audioController == nil {
            Debug.print("Configuring audio session")

            audioController = AudioController(
                data: self.data,
                /*
                onSpeakerActivationChanged: { on in
                    self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_SPEAKER, [ "isActivate": on ])
                }
                */
            )
        } else {
            let didUpdate = audioController?.maybeResetupAudioSession()
            if didUpdate == false {
                Debug.print("Audio session already configured")
            } else {
                Debug.print("Audio session updated")
            }
        }
    }

    /// Checks for the presence of audio output hardware.
    ///
    /// Because this method is exposed to Objective-C, it returns `NSNumber?`
    /// to allow for three distinct states:
    ///
    /// - **Value 1 (True):** Audio output is detected.
    /// - **Value 0 (False):** No audio output detected.
    /// - **Value nil:** The state is indeterminate or unknown.
    ///
    /// **Note for Swift callers:** Access the underlying boolean state
    /// using `.boolValue` after unwrapping the optional.
    @objc public func hasAudioOutput() -> NSNumber? {
        guard let result = audioController?.hasAudioOutput() else {
            return nil // Represents nil in Objective-C
        }
        return NSNumber(value: result)
    }

    public func saveEndCall(_ uuid: String, _ reason: Int) {
        switch reason {
        case 1:
            self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.failed)
            break
        case 2, 6:
            self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.remoteEnded)
            break
        case 3:
            self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.unanswered)
            break
        case 4:
            self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.answeredElsewhere)
            break
        case 5:
            self.sharedProvider?.reportCall(with: UUID(uuidString: uuid)!, endedAt: Date(), reason: CXCallEndedReason.declinedElsewhere)
            break
        default:
            break
        }
    }
    
    
    func endCallNotExist(_ data: Data) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(data.duration)) {
            let call = self.callManager.callWithUUID(uuid: UUID(uuidString: data.uuid)!)
            if (call != nil && self.answerCall == nil && self.outgoingCall == nil) {
                self.callEndTimeout(data)
            }
        }
    }
    
    
    
    func callEndTimeout(_ data: Data) {
        self.saveEndCall(data.uuid, 3)
        guard let call = self.callManager.callWithUUID(uuid: UUID(uuidString: data.uuid)!) else {
            return
        }
        self.showMissedCallNotification(data)
        sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TIMEOUT, data.toJSON())
        if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
            appDelegate.onTimeOut(call)
        }
        
        deactivateAudioSession()
    }
    
    @discardableResult
    public func reportCallEnd(_ uuid: String?) -> Bool {
        let effectiveUuid = uuid ?? self.data?.uuid
        
        if effectiveUuid != nil {
            self.saveEndCall(effectiveUuid!, 2)
            return true
        } else {
            return false
        }
    }
    
    /// Notifies the provider that an incoming call failed to connect.
    ///
    /// Use this when an external event causes the call to terminate before it is answered.
    public func reportCallFailed(_ data: flutter_callkit_incoming.Data) {
        self.saveEndCall(data.uuid, 1)
        sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_FAILED, data.toJSON())
    }
    
    func initCallkitProvider(_ data: Data) {
        if (self.sharedProvider == nil) {
            self.sharedProvider = CXProvider(configuration: createConfiguration(data))
            // Passing nil for the queue defaults execution to the main queue (DispatchQueue.main)
            self.sharedProvider?.setDelegate(self, queue: nil)
        } else if (data.checkIsDataForConfigurationChange(self.sharedProvider?.configuration)) {
            self.sharedProvider?.configuration = createConfiguration(data)
        }
        self.callManager.setSharedProvider(self.sharedProvider!)
    }
    
    func createConfiguration(_ data: Data) -> CXProviderConfiguration {
        let configuration = CXProviderConfiguration(localizedName: data.appName)
        configuration.supportsVideo = data.supportsVideo
        configuration.maximumCallGroups = data.maximumCallGroups
        configuration.maximumCallsPerCallGroup = data.maximumCallsPerCallGroup
        
        configuration.supportedHandleTypes = data.supportedHandleTypes
        if #available(iOS 11.0, *) {
            configuration.includesCallsInRecents = data.includesCallsInRecents
        }
        if !data.iconName.isEmpty {
            if let image = UIImage(named: data.iconName) {
                configuration.iconTemplateImageData = image.pngData()
            } else {
                Debug.print("Unable to load icon \(data.iconName).");
            }
        }
        if !data.ringtonePath.isEmpty || data.ringtonePath != "system_ringtone_default"  {
            configuration.ringtoneSound = data.ringtonePath
        }
        return configuration
    }
    
    func sendDefaultAudioInterruptionNotificationToStartAudioResource(){
        var userInfo : [AnyHashable : Any] = [:]
        let intrepEndeRaw = AVAudioSession.InterruptionType.ended.rawValue
        userInfo[AVAudioSessionInterruptionTypeKey] = intrepEndeRaw
        userInfo[AVAudioSessionInterruptionOptionKey] = AVAudioSession.InterruptionOptions.shouldResume.rawValue
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: self, userInfo: userInfo)
    }
    
    public func activateAudioSession(duckOthers: Bool = true) -> Bool? {
        if data?.configureAudioSession != false {
            audioController?.setupAudioSession(duckOthers: duckOthers, data: self.data)
        }

        return nil
    }
    
    func reactivateAudioSession() -> Bool? {
        return activateAudioSession()
    }
    
    public func deactivateAudioSession() {
        if data?.configureAudioSession != false {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setActive(
                    false,
                    options: AVAudioSession.SetActiveOptions.notifyOthersOnDeactivation
                )
            } catch {
                Debug.print(error)
                SwiftFlutterCallkitIncomingPlugin.onAudioSessionConfigurationError?(error as NSError?)
            }
        }
    }
    
    /*
    public func setSpeaker(_ on: Bool) {
        audioController?.setSpeaker(on: on)
    }
    */

    // MARK: - CXProviderDelegate

    public func providerDidReset(_ provider: CXProvider) {
        Debug.print("Provider did reset")

        /*
         End any ongoing calls if the provider resets, and remove them from the app's list of calls
         because they are no longer valid.
         */
        for call in callManager.calls {
            call.notifyEnded()
        }

        // Remove all calls from the app's list of calls.
        callManager.removeAllCalls()
    }

    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let data: Data = self.outgoingCallData ?? self.data!

        // Create and configure an instance of SpeakerboxCall to represent the new outgoing call.
        let call = Call(uuid: action.callUUID, data: data, isOutGoing: true)
        call.handle = action.handle.value

        Debug.print("May be configure audio session to start the call")
        /*
         Configure the audio session but do not start call audio here.
         Call audio should not be started until the audio session is activated by the system,
         after having its priority elevated.
         */
        configureAudioSession()

        /*
         Set callbacks for significant events in the call's lifecycle,
         so that the CXProvider can be updated to reflect the updated state.
         */
        call.hasStartedConnectingDidChange = { [weak self] in
            self?.sharedProvider?.reportOutgoingCall(with: call.uuid, startedConnectingAt: call.connectingDate)
        }
        call.hasConnectedDidChange = { [weak self] in
            self?.sharedProvider?.reportOutgoingCall(with: call.uuid, connectedAt: call.connectDate)
        }

        self.outgoingCall = call;

        if let callDelegate = self.callDelegate {
            callDelegate.startCall(call, action) {
                // Add the new outgoing call to the app's list of calls.
                self.callManager.addCall(call)

                self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_START, data.toJSON())
            }
        } else {
            // Signal to the system that the action was successfully performed.
            action.fulfill()

            // Add the new outgoing call to the app's list of calls.
            self.callManager.addCall(call)

            self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_START, data.toJSON())

            call.notifyConnecting()
            call.notifyConnected()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // Retrieve the Call instance corresponding to the action's call UUID.
        guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }

        Debug.print("May be configure audio session to accept/answer the call")
        /*
         Configure the audio session but do not start call audio here.
         Call audio should not be started until the audio session is activated by the system,
         after having its priority elevated.
         */
        configureAudioSession()

        self.data?.isAccepted = true
        self.answerCall = call
        call.hasConnected = true
        sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ACCEPT, self.data?.toJSON())

        // Signal to the system that the action was successfully performed.
        if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
            appDelegate.onAccept(call, action)
        } else {
            action.fulfill()
        }
    }
    
    /// Triggered when a user or the system attempts to end a call, such as tapping the "End" button on the CallKit UI
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if self.callManager.didCallWithUuidEnd(action.callUUID) {
            action.fulfill()
            return
        }

        // Retrieve the Call instance corresponding to the action's call UUID
        guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else {
            if (self.answerCall == nil && self.outgoingCall == nil) {
                sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TIMEOUT, self.data?.toJSON())
            } else {
                sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, self.data?.toJSON())
            }
            action.fail()
            return
        }

        call.notifyEnded()

        if (self.answerCall == nil && self.outgoingCall == nil) {
            sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_DECLINE, self.data?.toJSON())
            if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
                appDelegate.onDecline(call, action)
            } else {
                action.fulfill()
            }
        } else {
            self.answerCall = nil
            sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, call.data.toJSON())
            if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
                appDelegate.onEnd(call, action)
            } else {
                action.fulfill()
            }
        }

        // Remove the ended call from the app's list of calls.
        self.callManager.removeCall(call)
    }
    
    
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        // Retrieve the Call instance corresponding to the action's call UUID
        guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }

        // Update the Call's underlying hold state.
        call.isOnHold = action.isOnHold
        call.isMuted = action.isOnHold

        sendEvent(
            SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_HOLD,
            [
                "id": action.callUUID.uuidString,
                "isOnHold": action.isOnHold
            ]
        )

        // Signal to the system that the action has been successfully performed.
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        // Retrieve the Call instance corresponding to the action's call UUID
        guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }

        call.isMuted = action.isMuted

        sendMuteEvent(action.callUUID.uuidString, action.isMuted)

        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
        guard (self.callManager.callWithUUID(uuid: action.callUUID)) != nil else {
            action.fail()
            return
        }

        self.sendEvent(
            SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_GROUP,
            [
                "id": action.callUUID.uuidString,
                "callUUIDToGroupWith" : action.callUUIDToGroupWith?.uuidString
            ]
        )

        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        guard (self.callManager.callWithUUID(uuid: action.callUUID)) != nil else {
            action.fail()
            return
        }

        self.sendEvent(
            SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_DMTF,
            [
                "id": action.callUUID.uuidString,
                "digits": action.digits,
                "type": action.type.rawValue
            ]
        )

        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        guard let call = self.callManager.callWithUUID(uuid: action.uuid) else {
            action.fail()
            return
        }

        sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TIMEOUT, self.data?.toJSON())

        if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
            appDelegate.onTimeOut(call)
        }

        action.fulfill()
    }
    
    // Called when AVAudioSession.setActive to true.
    // It's means that the provider’s audio session is activated.
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        if(self.answerCall?.hasConnected ?? false){
            sendDefaultAudioInterruptionNotificationToStartAudioResource()
            return
        }
        if(self.outgoingCall?.hasConnected ?? false){
            sendDefaultAudioInterruptionNotificationToStartAudioResource()
            return
        }

        sendDefaultAudioInterruptionNotificationToStartAudioResource()

        Debug.print("Audio session is active.")

        if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
            appDelegate.didActivateAudioSession(audioSession)
        }

        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_AUDIO_SESSION, [ "isActivate": true ])
    }
    
    // Called when AVAudioSession.setActive to false.
    // It's means that the provider’s audio session is deactivated.
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
            appDelegate.didDeactivateAudioSession(audioSession)
        }

        audioController?.removeAudioSessionObservers()

        if self.outgoingCall?.isOnHold ?? false || self.answerCall?.isOnHold ?? false{
            Debug.print("Call is on hold")
            return
        }
        
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_AUDIO_SESSION, [ "isActivate": false ])
    }
    
    private func sendMuteEvent(_ id: String, _ isMuted: Bool) {
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_MUTE, [ "id": id, "isMuted": isMuted ])
    }
    
    @objc public func sendCallbackEvent(_ data: [String: Any]?) {
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_CALLBACK, data)
    }
    
    
    private func requestNotificationPermission(_ map: [String: Any]) {
        CallkitNotificationManager.shared.requestNotificationPermission(map)
    }
    
    
    private func showMissedCallNotification(_ data: Data) {
        if(!data.isShowMissedCallNotification){
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = data.nameCaller
        content.body = data.missedNotificationSubtitle
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "MISSED_CALL_CATEGORY"
        content.userInfo = data.toJSON()

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: data.uuid,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Debug.print("Error scheduling missed call notification: \(error)")
            } else {
                Debug.print("Missed call notification scheduled.")
            }
        }
    }
    
}

class EventCallbackHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    public func send(_ event: String, _ body: Any) {
        let data: [String : Any] = [
            "event": event,
            "body": body
        ]
        eventSink?(data)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

@objc public enum InvalidError: Int, Error {
    case uuid
}
