import Flutter
import UIKit
import CallKit
import AVFoundation

@available(iOS 10.0, *)
public class SwiftFlutterCallkitIncomingPlugin: NSObject, FlutterPlugin, CXProviderDelegate {
    
    static let ACTION_DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP = "com.hiennv.flutter_callkit_incoming.DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP"
    
    static let ACTION_CALL_INCOMING = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_INCOMING"
    static let ACTION_CALL_START = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_START"
    static let ACTION_CALL_ACCEPT = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT"
    static let ACTION_CALL_DECLINE = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_DECLINE"
    static let ACTION_CALL_ENDED = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ENDED"
    static let ACTION_CALL_TIMEOUT = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TIMEOUT"
    static let ACTION_CALL_CUSTOM = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_CUSTOM"
    
    static let ACTION_CALL_TOGGLE_HOLD = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_HOLD"
    static let ACTION_CALL_TOGGLE_MUTE = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_MUTE"
    static let ACTION_CALL_TOGGLE_DMTF = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_DMTF"
    static let ACTION_CALL_TOGGLE_GROUP = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_GROUP"
    static let ACTION_CALL_TOGGLE_AUDIO_SESSION = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_TOGGLE_AUDIO_SESSION"
    
    static let PUSH_KIT_INCOMING_CALL = "com.hiennv.flutter_callkit_incoming.PUSH_KIT_INCOMING_CALL"
    
    @objc public private(set) static var sharedInstance: SwiftFlutterCallkitIncomingPlugin!
    
    private var streamHandlers: WeakArray<EventCallbackHandler> = WeakArray([])
    
    private var callManager: CallManager
    
    private var sharedProvider: CXProvider? = nil
    
    private var outgoingCall : Call?
    private var answerCall : Call?
    
    private var data: Data?
    private var isFromPushKit: Bool = false
    private var silenceEvents: Bool = false
    private let devicePushTokenVoIP = "DevicePushTokenVoIP"

    public var uuid: String? {
        get {
            data?.uuid
        }
    }

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
            print(event, " silenced")
            return
        } else {
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
                result("OK")
                return
            }

            if let getArgs = args as? [String: Any] {
                self.data = Data(args: getArgs)
                showCallkitIncoming(
                    self.data!,
                    fromPushKit: false,
                    completion: { error in
                        if let error = error {
                            print("FlutterMethodCall.showCallkitIncoming", "error \(error) |> \(String(describing: error.localizedFailureReason))")

                            result(
                                FlutterError(
                                    code: String(error.code),
                                    message: error.localizedDescription,
                                    details: error.localizedFailureReason
                                )
                            )

                            return
                        }

                        result("OK")
                    }
                )
            }
            break
        case "showMissCallNotification":
            result("OK")
            break
        case "startCall":
            guard let args = call.arguments else {
                result("OK")
                return
            }
            if let getArgs = args as? [String: Any] {
                self.data = Data(args: getArgs)
                self.startCall(self.data!, fromPushKit: false)
            }
            result("OK")
            break
        case "endCall":
            guard let args = call.arguments else {
                result("OK")
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
                    result("OK")
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
                    print("Unexpected error: \(error)")
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
            guard let args = call.arguments as? [String: Any] ,
                  let callId = args["id"] as? String,
                  let isMuted = args["isMuted"] as? Bool else {
                result("OK")
                return
            }
            
            self.muteCall(callId, isMuted: isMuted)
            result("OK")
            break
        case "isMuted":
            guard let args = call.arguments as? [String: Any] ,
                  let callId = args["id"] as? String else{
                result(false)
                return
            }
            guard let callUUID = UUID(uuidString: callId),
                  let call = self.callManager.callWithUUID(uuid: callUUID) else {
                result(false)
                return
            }
            result(call.isMuted)
            break
        case "holdCall":
            guard let args = call.arguments as? [String: Any] ,
                  let callId = args["id"] as? String,
                  let onHold = args["isOnHold"] as? Bool else {
                result("OK")
                return
            }
            self.holdCall(callId, onHold: onHold)
            result("OK")
            break
        case "callConnected":
            guard let args = call.arguments else {
                result("OK")
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
            result("OK")
            break
        case "activeCalls":
            result(self.callManager.activeCalls())
            break;
        case "endAllCalls":
            self.callManager.endCallAlls()
            result("OK")
            break
        case "reportCallEnd":
            guard let args = call.arguments as? [String: Any],
                  let uuid = args["uuid"] as? String? else {
                result("OK")
                return
            }

            result(
                self.reportCallEnd(uuid)
            )
            break;
        case "getDevicePushTokenVoIP":
            result(self.getDevicePushTokenVoIP())
            break;
        case "silenceEvents":
            guard let silence = call.arguments as? Bool else {
                result("OK")
                return
            }
            
            self.silenceEvents = silence
            result("OK")
            break;
        case "requestNotificationPermission": 
            result("OK")
            break
         case "requestFullIntentPermission": 
            result("OK")
            break
        case "hideCallkitIncoming":
            result("OK")
            break
        case "endNativeSubsystemOnly":
            result("OK")
            break
        case "setAudioRoute":
            result("OK")
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
    
    @objc public func getAcceptedCall() -> Data? {
        NSLog("Call data ids \(String(describing: data?.uuid)) \(String(describing: answerCall?.uuid.uuidString))")
        if data?.uuid.lowercased() == answerCall?.uuid.uuidString.lowercased() {
            return data
        }
        return nil
    }
    
    @objc public func showCallkitIncoming(_ data: Data, fromPushKit: Bool, completion: ((NSError?) -> Void)?) {
        self.isFromPushKit = fromPushKit
        if(fromPushKit){
            self.data = data
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
        
        let uuid = UUID(uuidString: data.uuid)

        if (fromPushKit) {
            self.sendEvent(
                SwiftFlutterCallkitIncomingPlugin.PUSH_KIT_INCOMING_CALL,
                data.toJSON()
            )
        }
        
        activateAudioSession()

        self.sharedProvider?.reportNewIncomingCall(with: uuid!, update: callUpdate) { error in
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
    
    @objc public func startCall(_ data: Data, fromPushKit: Bool) {
        self.isFromPushKit = fromPushKit
        if(fromPushKit){
            self.data = data
        }
        initCallkitProvider(data)
        self.callManager.startCall(data)
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
    
    @objc public func endCall(_ data: Data) throws {
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
        
        let call = Call(uuid: uuid!, data: data)
        
        if (self.isFromPushKit) {
            self.isFromPushKit = false
            self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, data.toJSON())
        }

        self.callManager.endCall(call: call)
        
        deactivateAudioSession()
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
    
    @objc public func endAllCalls() {
        self.isFromPushKit = false
        self.callManager.endCallAlls()
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
        sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TIMEOUT, data.toJSON())
        if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
            appDelegate.onTimeOut(call)
        }
        
        deactivateAudioSession()
    }
    
    public func reportCallEnd(_ uuid: String?) -> Bool {
        let effectiveUuid = uuid ?? self.data?.uuid
        
        if effectiveUuid != nil {
            self.saveEndCall(effectiveUuid!, 2)
            return true
        } else {
            return false
        }
    }
    
    func initCallkitProvider(_ data: Data) {
        if (self.sharedProvider == nil) {
            self.sharedProvider = CXProvider(configuration: createConfiguration(data))
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
                print("Unable to load icon \(data.iconName).");
            }
        }
        if !data.ringtonePath.isEmpty || data.ringtonePath != "system_ringtone_default"  {
            configuration.ringtoneSound = data.ringtonePath
        }
        return configuration
    }
    
    func sendDefaultAudioInterruptionNofificationToStartAudioResource(){
        var userInfo : [AnyHashable : Any] = [:]
        let intrepEndeRaw = AVAudioSession.InterruptionType.ended.rawValue
        userInfo[AVAudioSessionInterruptionTypeKey] = intrepEndeRaw
        userInfo[AVAudioSessionInterruptionOptionKey] = AVAudioSession.InterruptionOptions.shouldResume.rawValue
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: self, userInfo: userInfo)
    }
    
    public func activateAudioSession(){
        if data?.configureAudioSession != false {
            let session = AVAudioSession.sharedInstance()
            do{
                try session.setCategory(AVAudioSession.Category.playAndRecord, options: [
                    .allowBluetoothA2DP,
                    .duckOthers,
                    .allowBluetooth,
                ])
                
                try session.setMode(self.getAudioSessionMode(data?.audioSessionMode))
                try session.setActive(data?.audioSessionActive ?? true)
                try session.setPreferredSampleRate(data?.audioSessionPreferredSampleRate ?? 44100.0)
                try session.setPreferredIOBufferDuration(data?.audioSessionPreferredIOBufferDuration ?? 0.005)
            }catch{
                print(error)
            }
        }
    }
    
    func reactivateAudioSession() {
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
                print(error)
            }
        }
    }
    
    func getAudioSessionMode(_ audioSessionMode: String?) -> AVAudioSession.Mode {
        var mode = AVAudioSession.Mode.default
        switch audioSessionMode {
        case "gameChat":
            mode = AVAudioSession.Mode.gameChat
            break
        case "measurement":
            mode = AVAudioSession.Mode.measurement
            break
        case "moviePlayback":
            mode = AVAudioSession.Mode.moviePlayback
            break
        case "spokenAudio":
            mode = AVAudioSession.Mode.spokenAudio
            break
        case "videoChat":
            mode = AVAudioSession.Mode.videoChat
            break
        case "videoRecording":
            mode = AVAudioSession.Mode.videoRecording
            break
        case "voiceChat":
            mode = AVAudioSession.Mode.voiceChat
            break
        case "voicePrompt":
            if #available(iOS 12.0, *) {
                mode = AVAudioSession.Mode.voicePrompt
            } else {
                // Fallback on earlier versions
            }
            break
        default:
            mode = AVAudioSession.Mode.default
        }
        return mode
    }
    
    public func providerDidReset(_ provider: CXProvider) {
        for call in self.callManager.calls {
            call.endCall()
        }
        self.callManager.removeAllCalls()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let call = Call(uuid: action.callUUID, data: self.data!, isOutGoing: true)
        call.handle = action.handle.value
        activateAudioSession()
        call.hasStartedConnectDidChange = { [weak self] in
            self?.sharedProvider?.reportOutgoingCall(with: call.uuid, startedConnectingAt: call.connectData)
        }
        call.hasConnectDidChange = { [weak self] in
            self?.sharedProvider?.reportOutgoingCall(with: call.uuid, connectedAt: call.connectedData)
        }
        self.outgoingCall = call;
        self.callManager.addCall(call)
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_START, self.data?.toJSON())
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else{
            action.fail()
            return
        }
        // self.reactivateAudioSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1200)) {
            self.reactivateAudioSession()
        }
        call.hasConnectDidChange = { [weak self] in
            self?.sharedProvider?.reportOutgoingCall(with: call.uuid, connectedAt: call.connectedData)
        }
        self.answerCall = call
        sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ACCEPT, self.data?.toJSON())
        if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
            appDelegate.onAccept(call, action)
        }else {
            action.fulfill()
        }
    }
    
//    private func checkUnlockedAndFulfill(action: CXAnswerCallAction, counter: Int) {
//        if UIApplication.shared.isProtectedDataAvailable {
//            action.fulfill()
//        } else if counter > 180 { // fail if waiting for more then 3 minutes
//            action.fail()
//        } else {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                self.checkUnlockedAndFulfill(action: action, counter: counter + 1)
//            }
//        }
//    }
    
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else {
            if(self.answerCall == nil && self.outgoingCall == nil){
                sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TIMEOUT, self.data?.toJSON())
            } else {
                sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, self.data?.toJSON())
            }
            action.fail()
            return
        }
        call.endCall()
        self.callManager.removeCall(call)
        if (self.answerCall == nil && self.outgoingCall == nil) {
            sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_DECLINE, self.data?.toJSON())
            if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
                appDelegate.onDecline(call, action)
            } else {
                action.fulfill()
            }
        }else {
            sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_ENDED, call.data.toJSON())
            if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
                appDelegate.onEnd(call, action)
            } else {
                action.fulfill()
            }
        }
    }
    
    
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let call = self.callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }
        call.isOnHold = action.isOnHold
        call.isMuted = action.isOnHold
        self.callManager.setHold(call: call, onHold: action.isOnHold)
        sendHoldEvent(action.callUUID.uuidString, action.isOnHold)
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
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
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_GROUP, [ "id": action.callUUID.uuidString, "callUUIDToGroupWith" : action.callUUIDToGroupWith?.uuidString])
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        guard (self.callManager.callWithUUID(uuid: action.callUUID)) != nil else {
            action.fail()
            return
        }
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_DMTF, [ "id": action.callUUID.uuidString, "digits": action.digits, "type": action.type ])
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

        if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
            appDelegate.didActivateAudioSession(audioSession)
        }

        if(self.answerCall?.hasConnected ?? false){
            sendDefaultAudioInterruptionNofificationToStartAudioResource()
            return
        }
        if(self.outgoingCall?.hasConnected ?? false){
            sendDefaultAudioInterruptionNofificationToStartAudioResource()
            return
        }
        self.outgoingCall?.startCall(withAudioSession: audioSession) {success in
            if success {
                self.callManager.addCall(self.outgoingCall!)
                self.outgoingCall?.startAudio()
            }
        }
        self.answerCall?.ansCall(withAudioSession: audioSession) { success in
            if success{
                self.answerCall?.startAudio()
            }
        }
        sendDefaultAudioInterruptionNofificationToStartAudioResource()
        activateAudioSession()

        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_AUDIO_SESSION, [ "isActivate": true ])
    }
    
    // Called when AVAudioSession.setActive to false.
    // It's means that the provider’s audio session is deactivated.
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        
        if let appDelegate = UIApplication.shared.delegate as? CallkitIncomingAppDelegate {
            appDelegate.didDeactivateAudioSession(audioSession)
        }

        if self.outgoingCall?.isOnHold ?? false || self.answerCall?.isOnHold ?? false{
            print("Call is on hold")
            return
        }
        
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_AUDIO_SESSION, [ "isActivate": false ])
    }
    
    private func sendMuteEvent(_ id: String, _ isMuted: Bool) {
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_MUTE, [ "id": id, "isMuted": isMuted ])
    }
    
    private func sendHoldEvent(_ id: String, _ isOnHold: Bool) {
        self.sendEvent(SwiftFlutterCallkitIncomingPlugin.ACTION_CALL_TOGGLE_HOLD, [ "id": id, "isOnHold": isOnHold ])
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
