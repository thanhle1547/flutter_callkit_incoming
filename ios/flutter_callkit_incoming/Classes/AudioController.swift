//
//  AudioController.swift
//  Pods
//
//  Created by Thanh Le on 26/4/26.
//

import AVFoundation

/// `AudioController` manages the AVAudioEngine lifecycle and audio session states for VoIP calls.
///
/// See Apple CallKit Sample - https://developer.apple.com/documentation/CallKit/voip-calling-with-callkit
/// See: WebRTC audio_device_ios.mm - https://chromium.googlesource.com/external/webrtc/+/34911ad55c4c4c549fe60e1b4cc127420b15666b/webrtc/modules/audio_device/ios/audio_device_ios.mm
class AudioController: NSObject {
    private var engine: AVAudioEngine?
    private var isAudioChainBeingReconstructed = false
    private var isAudioSessionObserved = false

    // private var onSpeakerToogled: ((Bool) -> Void)
    private var speakerEnabled: Bool = false

    private var isInitialized: Bool = false

    var isMuted: Bool = false {
        didSet {
            engine?.inputNode.volume = isMuted ? 0.0 : 1.0
        }
    }

    init(
        data: Data?
        /*
        onSpeakerActivationChanged: @escaping ((Bool) -> Void)
        */
    ) {
        // onSpeakerToogled = onSpeakerActivationChanged

        super.init()

        setupAudioSession(data: data)

        isInitialized = true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        isAudioSessionObserved = false
        isInitialized = false
    }

    // MARK: - Setup

    public func setupAudioSession(duckOthers: Bool = true, data: Data?) {
        let sessionInstance = AVAudioSession.sharedInstance()
        
        do {
            var options: AVAudioSession.CategoryOptions = [
                .allowBluetoothA2DP,
                // 'allowBluetooth' was deprecated in iOS 8.0: renamed to 'allowBluetoothHFP'
                .allowBluetoothHFP,
                .mixWithOthers
            ]
            if duckOthers {
                options.insert(.duckOthers)
            }

            try sessionInstance.setCategory(.playAndRecord, options: options)

            try sessionInstance.setMode(self.getAudioSessionMode(data?.audioSessionMode))
            try sessionInstance.setPreferredSampleRate(data?.audioSessionPreferredSampleRate ?? 44100.0) // 44.1kHz
            try sessionInstance.setPreferredIOBufferDuration(data?.audioSessionPreferredIOBufferDuration ?? 0.005) // 5 ms

        } catch {
            Debug.print("Error setting up audio session: \(error)")
            SwiftFlutterCallkitIncomingPlugin.onAudioSessionConfigurationError?(error as NSError?)
        }
    }

    /// Checks the current `AVAudioSession` configuration and applies necessary updates
    /// for voice communication if they are not already set.
    ///
    /// This method verifies that the category is set to `.playAndRecord` and the mode
    /// is set to `.voiceChat`. If either setting is incorrect, it attempts an update.
    ///
    /// - Returns:
    ///   - `true` if any configuration changes were successfully applied.
    ///   - `false` if the session was already correctly configured.
    ///   - `nil` if an error occurred during the update process.
    ///
    /// - Note: If this function is called while the session is already active, some
    ///   changes might not apply immediately or might cause a brief glitch.
    public func maybeResetupAudioSession() -> Bool? {
        let session = AVAudioSession.sharedInstance()

        var isDirty: Bool = false

        let desiredCategory = AVAudioSession.Category.playAndRecord
        let desiredMode = AVAudioSession.Mode.voiceChat

        do {
            if session.category != desiredCategory {
                Debug.print("Current Audio Session category is \(session.category), updating to .playAndRecord..")
                isDirty = true
                try session.setCategory(desiredCategory)
            }
            if session.mode != desiredMode {
                Debug.print("Current Audio Session mode is \(session.mode), updating to .voiceChat..")
                isDirty = true
                try session.setMode(desiredMode)
            }

            #if DEBUG
            let options = session.categoryOptions

            var mapping: [(option: AVAudioSession.CategoryOptions, name: String)] = [
                (.mixWithOthers, ".mixWithOthers"),
                (.duckOthers, ".duckOthers"),
                (.allowBluetoothHFP, ".allowBluetoothHFP"),
                (.defaultToSpeaker, ".defaultToSpeaker"),
                (.interruptSpokenAudioAndMixWithOthers, ".interruptSpokenAudioAndMixWithOthers"),
                (.allowBluetoothA2DP, ".allowBluetoothA2DP"),
                (.allowAirPlay, ".allowAirPlay"),
            ]
            if #available(iOS 14.5, *) {
                mapping.append(
                    (.overrideMutedMicrophoneInterruption, ".overrideMutedMicrophoneInterruption")
                )
            }

            // Filter and map the names
            let names = mapping
                .filter { options.contains($0.option) }
                .map { $0.name }
            let optionsString = names.isEmpty ? "<none>" : names.joined(separator: ", ")

            Debug.print("Current Audio Session category options is \(options), which is [ \(optionsString) ]")
            #endif

            return isDirty
        } catch {
            Debug.print("Error re-setting up audio session: \(error)")
            SwiftFlutterCallkitIncomingPlugin.onAudioSessionConfigurationError?(error as NSError?)

            return nil
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

    public func setSpeaker(on: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            // Only override the output port instead of resetting category/mode
            // This will cause:
            // Exception    NSException *    "required condition is false: [srcFormat isEqual:format]"    0x000000030314ad60
            // in restartAudioEngineWithNewFormat at
            // engine.connect(engine.inputNode, to: engine.mainMixerNode, format: newFormat)
            try session.overrideOutputAudioPort(
                on ? .speaker : .none
            )

            speakerEnabled = on

            // onSpeakerToogled(on)
        } catch {
            Debug.print("Error overriding output audio port: \(error)")
            SwiftFlutterCallkitIncomingPlugin.onAudioSessionConfigurationError?(error as NSError?)
        }
    }

    public func isSpeakerActive() -> Bool {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let result = outputs.contains { $0.portType == .builtInSpeaker }
        return result
    }

    public func hasAudioOutput() -> Bool {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        // Returns true if there is at least one output port available
        return !currentRoute.outputs.isEmpty
    }

    // MARK: - Notification Handlers

    public func setupAudioSessionObservers() {
        let sessionInstance = AVAudioSession.sharedInstance()

        // Notifications
        let nc = NotificationCenter.default

        if isAudioSessionObserved {
            nc.removeObserver(self)
        }

        isAudioSessionObserved = true

        // Add interruption handler.
        nc.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: sessionInstance
        )
        // Add the route change notification.
        nc.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: sessionInstance
        )
        // Rebuild the audio chain if media services are reset.
        nc.addObserver(
            self,
            selector: #selector(handleMediaServerReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: sessionInstance
        )
    }

    public func removeAudioSessionObservers() {
        let nc = NotificationCenter.default

        if isAudioSessionObserved {
            nc.removeObserver(self)
        }

        isAudioSessionObserved = false
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                }
            }
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        var validRouteChange = true

        Debug.print("Route change reason: \(reason)")
        Debug.print("Explanation:")
        var explanation: String = "\n"
        switch reason {
            case .newDeviceAvailable:
                // A headset or Bluetooth device was plugged in/connected.
                explanation = "A new device available"

            case .oldDeviceUnavailable:
                // A headset or Bluetooth device was unplugged.
                // The system usually pauses audio;
                // you may need to update your UI Speaker button state here.
                explanation = "The old device became unavailable"

            case .categoryChange:
                let category = AVAudioSession.sharedInstance().category
                explanation = "The audio category has changed"
                explanation += "\n"
                explanation = "New Category: \(category.rawValue)"
                validRouteChange = false

            case .override:
                explanation = "The route has been overridden (e.g. the output has been changed from the receiver, which is the default, to the speaker)."

            case .wakeFromSleep:
                explanation = "The device woke from sleep"

            case .noSuitableRouteForCategory:
                explanation = "There is no route for the current category (for instance, the category is .record but no input device is available)"

            case .routeConfigurationChange:
                explanation = "The device woke from sleep"
                validRouteChange = false

            default:
                break
        }
        Debug.print(explanation)

        let session = AVAudioSession.sharedInstance()

        // Check the CURRENT active route
        let currentRoute = session.currentRoute

        var connectedDevices: String = ""
        var deviceNumber: Int = 1
        for output in currentRoute.outputs {
            connectedDevices += "\(deviceNumber). "

            switch output.portType {
                case .headphones:
                    connectedDevices += "Wired Headphones/Headset"

                case .bluetoothA2DP:
                    connectedDevices += "Bluetooth that supporting high-quality stereo (AirPods, Speakers)"

                case .bluetoothHFP:
                    connectedDevices += "Bluetooth that supporting 2-way communication (Car Kits, Headsets)"

                case .builtInSpeaker:
                    connectedDevices += "Phone Speaker"
                    
                case .builtInReceiver:
                    connectedDevices += "Phone Earpiece - the small speaker at the top you hold to your ear during a call"

                default:
                    connectedDevices += "Other device (\(output.portType.rawValue))"
            }

            connectedDevices += "\n"
            deviceNumber += 1
        }
        
        connectedDevices += " (volume: \(session.outputVolume))"

        Debug.print("Current audio routes:")
        Debug.print(connectedDevices)

        if validRouteChange {
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey],
               let previousRouteDescription = previousRoute as? AVAudioSessionRouteDescription {
                Debug.print("Previous route was:")
                Debug.verbosePrint(previousRouteDescription)
            }

            // Only restart audio for a valid route change and if the
            // session sample rate has changed.

            // Get the current hardware sample rate from the session
            let sessionSampleRate: Double = session.sampleRate
            Debug.print("Session sample rate: \(sessionSampleRate)")

            // In AVAudioEngine, we check the input or output node's format
            // playout_parameters_.sample_rate() is equivalent to
            // engine.outputNode.outputFormat(forBus: 0).sampleRate
            //
            // playout_parameters_ is an instance of `AudioParameters`
            // that stores the configuration settings for audio playback (output)
            let currentEngineRate = engine?.outputNode.outputFormat(forBus: 0 /* for output */).sampleRate

            if currentEngineRate != sessionSampleRate {
                Debug.print(
                    "📊 Sample rate mismatch detected. Changed from \(String(describing: currentEngineRate))Hz to \(sessionSampleRate)Hz. May be `AVAudioSession` configuration changed!"
                )

                maybeResetupAudioSession()
            }
        }

        /*
        if speakerEnabled {
            if !isSpeakerActive() {
                onSpeakerToogled(false)

                Debug.print("Re-active speaker")
                setSpeaker(on: true)
            }
        }
        */
    }

    @objc private func handleMediaServerReset() {
        isAudioChainBeingReconstructed = true

        // Brief delay to allow system to recover
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
            self.maybeResetupAudioSession()
            self.isAudioChainBeingReconstructed = false
        }
    }
}
