//
//  CallManager.swift
//  flutter_callkit_incoming
//
//  Created by Hien Nguyen on 07/10/2021.
//

import Foundation
import CallKit

@available(iOS 10.0, *)
class CallManager: NSObject {
    
    private let callController = CXCallController()
    private var sharedProvider: CXProvider? = nil
    
    func setSharedProvider(_ sharedProvider: CXProvider) {
        self.sharedProvider = sharedProvider
    }

    // MARK: - Actions

    func startCall(_ data: Data) {
        let handle = CXHandle(type: self.getHandleType(data.handleType), value: data.getEncryptHandle())
        // Guard against malformed UUID strings — caller layers (Dart, native) sometimes pass
        // app-internal call identifiers that aren't UUID(8-4-4-4-12) shaped. Force-unwrapping
        // here would crash the host process (was the chronic SnowChat "iPhone caller endCall →
        // process dies" symptom before the Dart-side guard was added). Returning silently is
        // safe: no CallKit call gets registered, and the caller can detect the no-op via
        // its own state machine.
        guard let uuid = UUID(uuidString: data.uuid) else {
            Debug.print("[CallkitIncoming] startCall: invalid UUID '\(data.uuid)' — ignored")
            return
        }
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = data.type > 0
        startCallAction.contactIdentifier = data.nameCaller

        let callTransaction = CXTransaction()
        callTransaction.addAction(startCallAction)

        self.requestTransaction(callTransaction, action: "startCall", completion: { _ in
            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = handle
            callUpdate.supportsDTMF = data.supportsDTMF
            callUpdate.supportsHolding = data.supportsHolding
            callUpdate.supportsGrouping = data.supportsGrouping
            callUpdate.supportsUngrouping = data.supportsUngrouping
            callUpdate.hasVideo = data.type > 0 ? true : false
            callUpdate.localizedCallerName = data.nameCaller
            self.sharedProvider?.reportCall(with: uuid, updated: callUpdate)
        })
    }
    
    func updateCallerName(_ uuid: UUID, _ name: String) {
        let callUpdate = CXCallUpdate()
        callUpdate.localizedCallerName = name
        self.sharedProvider?.reportCall(with: uuid, updated: callUpdate)
    }

    func muteCall(call: Call, isMuted: Bool) {
        let muteAction = CXSetMutedCallAction(call: call.uuid, muted: isMuted)
        let callTransaction = CXTransaction()
        callTransaction.addAction(muteAction)

        self.requestTransaction(callTransaction, action: "muteCall")
    }
    
    /// - Parameters:
    ///   - call: The call to update on hold status for.
    ///   - onHold: Specifies whether the call should be placed on hold.
    func holdCall(call: Call, onHold: Bool) {
        let muteAction = CXSetHeldCallAction(call: call.uuid, onHold: onHold)
        let callTransaction = CXTransaction()
        callTransaction.addAction(muteAction)

        self.requestTransaction(callTransaction, action: "holdCall")
    }
    
    /// Requests the system to end a call based on a user action.
    ///
    /// This function submits a `CXTransaction` containing a `CXEndCallAction`. If successful,
    /// the system calls `provider(_:perform:)` to finalize the termination.
    ///
    /// - Parameter call: The call to end.
    func endCall(callId: UUID, completion: ((Bool) -> Void)? = nil) {
        if didCallWithUuidEnd(callId) {
            return
        }

        endCallIds.insert(callId)

        let endCallAction = CXEndCallAction(call: callId)
        let callTransaction = CXTransaction()
        callTransaction.addAction(endCallAction)

        self.requestTransaction(callTransaction, action: "endCall", completion: completion)
    }
    
    func connectedCall(call: Call) {
        let callItem = self.callWithUUID(uuid: call.uuid)
        callItem?.notifyConnected()
        
        let answerAction = CXAnswerCallAction(call: call.uuid)        
        let transaction = CXTransaction(action: answerAction)

        callController.request(transaction) { error in
            if let error = error {
                Debug.print("Error answering call: \(error)")
            } else {
                // Call successfully answered
            }
        }
    }
    
    func endCallAlls() {
        let calls = callController.callObserver.calls
        for call in calls {
            let endCallAction = CXEndCallAction(call: call.uuid)
            let callTransaction = CXTransaction()
            callTransaction.addAction(endCallAction)
            self.requestTransaction(callTransaction, action: "endCallAlls")
        }
    }
    
    func activeCalls() -> [[String: Any]] {
        let calls = callController.callObserver.calls
        var json = [[String: Any]]()
        for call in calls {
            let callItem = self.callWithUUID(uuid: call.uuid)
            if(callItem != nil){
                var item: [String: Any] = callItem!.data.toJSON()
                item["accepted"] = callItem?.hasConnected
                json.append(item)
            }else {
                let item: [String: String] = ["id": call.uuid.uuidString]
                json.append(item)
            }
        }
        return json
    }

    func setHold(call: Call, onHold: Bool) {
        let handleCall = CXSetHeldCallAction(call: call.uuid, onHold: onHold)
        let callTransaction = CXTransaction()

        callTransaction.addAction(handleCall)
    }

    /// Requests that the actions in the specified transaction be asynchronously performed by the telephony provider.
    /// - Parameter transaction: A transaction that contains actions to be performed.
    private func requestTransaction(_ transaction: CXTransaction, action: String, completion: ((Bool) -> Void)? = nil) {
        callController.request(transaction) { error in
            if let error = error {
                Debug.print("Error requesting transaction: \(error)")
            } else {
                Debug.print("Requested transaction successfully: \(action)")
            }

            completion?(error == nil)
        }
    }
    
    private func getHandleType(_ handleType: String?) -> CXHandle.HandleType {
        var typeDefault = CXHandle.HandleType.generic
        switch handleType {
        case "number":
            typeDefault = CXHandle.HandleType.phoneNumber
            break
        case "email":
            typeDefault = CXHandle.HandleType.emailAddress
        default:
            typeDefault = CXHandle.HandleType.generic
        }
        return typeDefault
    }
    
    // MARK: - Call Management

    /// A publisher of active calls.
    private(set) var calls = [Call]()

    /// A publisher of end calls.
    private(set) var endCallIds: Set<UUID> = Set<UUID>()

    static let callsChangedNotification = Notification.Name("CallsChangedNotification")
    var callsChangedHandler: (() -> Void)?
    
    /// Returns the call with the specified UUID if it exists.
    /// - Parameter uuid: The call's unique identifier.
    /// - Returns: The call with the specified UUID if it exists, otherwise `nil`.
    func callWithUUID(uuid: UUID) -> Call? {
        guard let idx = calls.firstIndex(where: { $0.uuid == uuid }) else { return nil }
        return calls[idx]
    }

    public func didCallWithUuidEnd(_ uuid: UUID) -> Bool {
        let containsInSet = endCallIds.contains(uuid)
        return containsInSet
    }

    /// Adds a call to the array of active calls.
    /// - Parameter call: The call  to add.
    func addCall(_ call: Call){
        calls.append(call)

        call.stateDidChange = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.callsChangedHandler?()
            strongSelf.postCallNotification()
        }

        callsChangedHandler?()
        postCallNotification()
    }
    
    /// Removes a call from the array of active calls if it exists.
    /// - Parameter call: The call to remove.
    func removeCall(_ call: Call) {
        if didCallWithUuidEnd(call.uuid) {
            return
        }

        endCallIds.insert(call.uuid)

        guard let idx = calls.firstIndex(where: { $0 === call }) else { return }
        calls.remove(at: idx)
        callsChangedHandler?()
        postCallNotification()
    }
    
    /// Empties the array of active calls.
    func removeAllCalls() {
        calls.removeAll()
        callsChangedHandler?()
        postCallNotification()
    }
    
    private func postCallNotification(){
        NotificationCenter.default.post(name: type(of: self).callsChangedNotification, object: self)
    }
}
