//
//  CallkitIncomingCallDelegeate.swift
//  Pods
//
//  Created by Thanh Le on 26/4/26.
//

import CallKit

public protocol CallkitIncomingCallDelegate : NSObjectProtocol {
    func startCall(_ call: Call, _ action: CXStartCallAction, _ onFulfill: (() -> Void));
}
