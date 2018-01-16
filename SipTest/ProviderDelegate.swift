//
//  ProviderDelegate.swift
//  SipTest
//
//  Created by Zhe Cui on 12/20/17.
//  Copyright © 2017 Zhe Cui. All rights reserved.
//

import Foundation
import UIKit
import CallKit
import AVFoundation

final class ProviderDelegate: NSObject, CXProviderDelegate {
    private let provider: CXProvider
    private var callID = pjsua_call_id()
    
    override init() {
        provider = CXProvider(configuration: type(of: self).providerConfiguration)
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
    }
    
    static var providerConfiguration: CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration(localizedName: "ButterflyMX")
        
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.supportedHandleTypes = [.phoneNumber]
        //providerConfiguration.iconTemplateImageData = UIImagePNGRepresentation(UIImage(named: "call_kit_logo")!)
        
        return providerConfiguration
    }
    
    func reportIncomingCall(callID: pjsua_call_id, uuid: UUID, handle: String, hasVideo: Bool = false, completion: ((NSError?) -> Void)?) {
        let update = CXCallUpdate()
        self.callID = callID
        
        update.localizedCallerName = handle
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.hasVideo = hasVideo
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            completion?(error as NSError?)
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, mode: AVAudioSessionModeVoiceChat)
            //try AVAudioSession.sharedInstance().setActive(true) // TODO: Why error when setActive?
        } catch {
            print("Divert audio to Speaker error: \(error)")
            fatalError()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        
        configureAudioSession()
        
        // Enable Video
        var opt = pjsua_call_setting()

        pjsua_call_setting_default(&opt)
        //opt.aud_cnt = app_config.aud_cnt
        opt.vid_cnt = 1

        let status = pjsua_call_answer2(callID, &opt, 200, nil, nil)
//        let status = pjsua_call_answer(callID, 200, nil, nil)
        
        if status == PJ_SUCCESS.rawValue {
            action.fulfill()
        } else {
            print("Error get sound dev IDs, status: \(status)")
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let captureDeviceID = AppDelegate.shared.captureDeviceID
        let playbackDeviceID = AppDelegate.shared.playbackDeviceID
        
        let status = pjsua_set_snd_dev(captureDeviceID, playbackDeviceID)
        if status != PJ_SUCCESS.rawValue {
            print("Error set sound dev, status: \(status)")
            fatalError()
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("Provider did deactivate audio session.")
        pjsua_set_no_snd_dev()
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        print("Provider did Begin.")
    }
    
    func providerDidReset(_ provider: CXProvider) {
        print("Provider did Reset.")
    }

}
