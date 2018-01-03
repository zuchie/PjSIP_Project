//
//  Callbacks.swift
//  SipTest
//
//  Created by Zhe Cui on 12/18/17.
//  Copyright © 2017 Zhe Cui. All rights reserved.
//

import Foundation
import UIKit

enum SIPNotification: String {
    case incomingCall = "SIPIncomingCallNotification"
    case callState = "SIPCallStateNotification"
    case registrationState = "SIPRegistrationStateNotification"
    
    var notification: Notification.Name {
        return Notification.Name(rawValue: self.rawValue)
    }
}

func onIncomingCall(accountID: pjsua_acc_id, callID: pjsua_call_id, rData: UnsafeMutablePointer<pjsip_rx_data>?) {
    print("== On incoming call")
    
    var callInfo = pjsua_call_info()
    pjsua_call_get_info(callID, &callInfo)
    
    let remoteInfo = String(cString: callInfo.remote_info.ptr)
    
    let startIndex = remoteInfo.index(after: remoteInfo.index(of: "<")!)
    let endIndex = remoteInfo.index(of: ">")!
    
    let remoteAddress = remoteInfo[startIndex..<endIndex].components(separatedBy: ":").last!
    
//    let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
//    DispatchQueue.main.asyncAfter(wallDeadline: DispatchWallTime.now() + 0) {
////        AppDelegate.shared.displayIncomingCall(uuid: UUID(), handle: handle, hasVideo: videoEnabled) { _ in
////            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
////        }
//        AppDelegate.shared.providerDelegate.reportIncomingCall(callID: callID, uuid: UUID(), handle: remoteAddress, hasVideo: true) { _ in
//            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
//        }
//    }
    
    DispatchQueue.main.async {
        AppDelegate.shared.providerDelegate.reportIncomingCall(callID: callID, uuid: UUID(), handle: remoteAddress, hasVideo: true, completion: nil)
    }
    
//    DispatchQueue.main.async {
//        NotificationCenter.default.post(name: SIPNotification.incomingCall.notification, object: nil, userInfo: ["callID" : callID, "remoteAddress" : remoteAddress])
//    }
}

func onCallState(callID: pjsua_call_id, event: UnsafeMutablePointer<pjsip_event>?) {
    var callInfo = pjsua_call_info()
    pjsua_call_get_info(callID, &callInfo)

    DispatchQueue.main.async {
        NotificationCenter.default.post(name: SIPNotification.callState.notification, object: nil, userInfo: ["callID" : callID, "state" : callInfo.state])
    }
}

func onCallMediaState(callID: pjsua_call_id) {
    var callInfo = pjsua_call_info()
    pjsua_call_get_info(callID, &callInfo)

    if callInfo.media_status == PJSUA_CALL_MEDIA_ACTIVE {
        pjsua_conf_connect(callInfo.conf_slot, 0)
        pjsua_conf_connect(0, callInfo.conf_slot)
    }
}

func onRegState(accountID: pjsua_acc_id) {
    var status = pj_status_t()
    var info = pjsua_acc_info()
    
    status = pjsua_acc_get_info(accountID, &info)
    
    if status != PJ_SUCCESS.rawValue {
        print("Error registration status: \(status)")
        
        return
    }
    
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: SIPNotification.registrationState.notification, object: nil, userInfo: ["accountID" : accountID, "statusText" : String(cString: info.status_text.ptr), "status" : info.status])
    }
}
