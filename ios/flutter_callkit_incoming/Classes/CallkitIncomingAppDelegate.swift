//
//  CallkitIncomingAppDelegate.swift
//  flutter_callkit_incoming
//
//  Created by Hien Nguyen on 05/01/2024.
//

import Foundation
import AVFAudio
import CallKit


public protocol CallkitIncomingAppDelegate : NSObjectProtocol {
    
    func onBeforeSendAcceptEvent(_ call: Call, _ action: CXAnswerCallAction);

    func onAccept(_ call: Call, _ action: CXAnswerCallAction);
    
    func onMuted(_ call: Call, _ action: CXSetMutedCallAction)
    
    func onDecline(_ call: Call, _ action: CXEndCallAction);
    
    func onEnd(_ call: Call, _ action: CXEndCallAction);
    
    func onTimeOut(_ call: Call);

    func didActivateAudioSession(_ audioSession: AVAudioSession)
    
    func didDeactivateAudioSession(_ audioSession: AVAudioSession)
    
    func providerDidReset()

}
