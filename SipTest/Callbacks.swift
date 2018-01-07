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
    case incomingVideo = "SIPIncomingVideoNotification"
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
//        if wid != PJSUA_INVALID_ID.rawValue {
//            NotificationCenter.default.post(name: SIPNotification.incomingVideo.notification, object: nil, userInfo: ["callID" : callID, "remoteAddress" : remoteAddress, "windowID" : wid])
//            //AppDelegate.shared.displayWindow(wid)
//        } else {
            AppDelegate.shared.providerDelegate.reportIncomingCall(callID: callID, uuid: UUID(), handle: remoteAddress, hasVideo: true, completion: nil)
//        }
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

func displayWindow(_ wid: pjsua_vid_win_id) {
    //#if PJSUA_HAS_VIDEO
    var i: CInt = 0
    var last: CInt = 0
    
    i = (wid == PJSUA_INVALID_ID.rawValue) ? 0 : wid
    last = (wid == PJSUA_INVALID_ID.rawValue) ? PJSUA_MAX_VID_WINS : wid + 1
    
    while i < last {
        var wi = pjsua_vid_win_info()
        
        if (pjsua_vid_win_get_info(i, &wi) == PJ_SUCCESS.rawValue) {
            //  C UnsafeMutableRawPointer to Swift Object
            let videoView = Unmanaged<UIView>.fromOpaque(wi.hwnd.info.ios.window).takeUnretainedValue()
            
            DispatchQueue.main.async {
                /* Add the video window as subview */
                videoView.isHidden = false

                guard var topVC = UIApplication.shared.keyWindow?.rootViewController else {
                    fatalError()
                }
                
                while let presentedViewController = topVC.presentedViewController {
                    topVC = presentedViewController
                }
                
                topVC.view.addSubview(videoView)
                
                if wi.is_native == PJ_FALSE.rawValue {
                    /* Resize it to fit width */
                    videoView.bounds = CGRect(x: 0, y: 0, width: topVC.view.bounds.size.width, height: topVC.view.bounds.size.height * 1.0 * topVC.view.bounds.size.width / videoView.bounds.size.width)
                    /* Center it horizontally */
                    videoView.center = CGPoint(x: topVC.view.bounds.size.width / 2.0, y: videoView.bounds.size.height / 2.0)
//                    // Show window
//                    print("i: \(i)")
//                    pjsua_vid_win_set_show(i, pj_bool_t(PJ_TRUE.rawValue))
                } else {
                    /* Preview window, move it to the bottom */
                    videoView.center = CGPoint(x: topVC.view.bounds.size.width / 2.0, y: topVC.view.bounds.size.height - videoView.bounds.size.height / 2.0)
                }
            }
        }
        
        i += 1
    }
    //#endif
}

/* arrange windows. arg:
 *   -1:    arrange all windows
 *   != -1: arrange only this window id
 */
func arrange_window(_ wid: pjsua_vid_win_id) {
//    #if PJSUA_HAS_VIDEO
    var pos = pjmedia_coord()
    var last = 0
        
    pos.x = 0
    pos.y = 10
    
    last = Int((wid == PJSUA_INVALID_ID.rawValue) ? PJSUA_MAX_VID_WINS : wid)
    
    for i in 0..<last {
        var wi = pjsua_vid_win_info()
        var status = pj_status_t()
        
        status = pjsua_vid_win_get_info(pjsua_vid_win_id(i), &wi)
        if status != PJ_SUCCESS.rawValue { continue }
        
        if wi.is_native == PJ_FALSE.rawValue {
            // Show window
            print("i: \(i)")
            status = pjsua_vid_win_set_show(pjsua_vid_win_id(i), pj_bool_t(PJ_TRUE.rawValue))
            if status != PJ_SUCCESS.rawValue { fatalError() }
            
            wi.show = pj_bool_t(PJ_TRUE.rawValue)
        }
        
        if wid == PJSUA_INVALID_ID.rawValue {
            pjsua_vid_win_set_pos(pjsua_vid_win_id(i), &pos)
        }
        
        if wi.show == pj_bool_t(PJ_TRUE.rawValue) {
            pos.y += Int32(wi.size.h)
        }
    }
    
    if (wid != PJSUA_INVALID_ID.rawValue) {
        pjsua_vid_win_set_pos(wid, &pos)
    }
    
    //NotificationCenter.default.post(name: SIPNotification.incomingVideo.notification, object: nil, userInfo: ["windowID" : wid])

    displayWindow(wid)
//#endif
}

func on_call_audio_state(_ ci: pjsua_call_info, _ mi: Int, _ has_error: pj_bool_t) {
    if ci.media_status == PJSUA_CALL_MEDIA_ACTIVE {
        pjsua_conf_connect(ci.conf_slot, 0)
        pjsua_conf_connect(0, ci.conf_slot)
    }
}

func on_call_video_state(_ ci: pjsua_call_info, _ mi: Int, _ has_error: pj_bool_t) {
    
//#if true
    if ci.media_status != PJSUA_CALL_MEDIA_ACTIVE { return }

    var wid: pjsua_vid_win_id = PJSUA_INVALID_ID.rawValue
    var mediaTuple = ci.media

    let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
        let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)

        return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
    }

    wid = media[mi].stream.vid.win_in
    
    // Incoming video window
    arrange_window(wid)
//#else
    
    // Preview window
    let dev_id = 0
    var param = pjsua_vid_preview_param()

    pjsua_vid_preview_param_default(&param)
    param.wnd_flags = PJMEDIA_VID_DEV_WND_BORDER.rawValue | PJMEDIA_VID_DEV_WND_RESIZABLE.rawValue
    pjsua_vid_preview_start(pjmedia_vid_dev_index(dev_id), &param)

    arrange_window(pjsua_vid_preview_get_win(pjmedia_vid_dev_index(dev_id)))
//#endif
    
    // Re-invite
//    var para = pjsua_call_vid_strm_op_param()
//    var si = pjsua_stream_info()
//    var status: pj_status_t = pj_status_t(PJ_SUCCESS.rawValue)
//
//    pjsua_call_vid_strm_op_param_default(&para)
    
//    para.med_idx = 0
//    if ((pjsua_call_get_stream_info(ci.id, UInt32(para.med_idx), &si) == PJ_FALSE.rawValue) || si.type != PJMEDIA_TYPE_VIDEO) {
//        return
//    }
    
    // TODO: pete - only have decoding dir now
//    let dir = si.info.vid.dir
//    para.dir = pjmedia_dir(rawValue: pjmedia_dir.RawValue(UInt8(dir.rawValue) | UInt8(PJMEDIA_DIR_DECODING.rawValue)))
//    
//    status = pjsua_call_set_vid_strm(ci.id, PJSUA_CALL_VID_STRM_CHANGE_DIR, &para)
//
//    if status != PJ_SUCCESS.rawValue {
//        fatalError()
//    }
}

func onCallMediaState(callID: pjsua_call_id) {
    var callInfo = pjsua_call_info()
    let has_error: pj_bool_t = pj_bool_t(PJ_FALSE.rawValue)
    
    pjsua_call_get_info(callID, &callInfo)
    
    var mediaTuple = callInfo.media
    let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
        let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
        
        return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
    }

    for mi in 0..<Int(callInfo.media_cnt) {
        switch media[Int(mi)].type {
        case PJMEDIA_TYPE_AUDIO:
            on_call_audio_state(callInfo, mi, has_error)
        case PJMEDIA_TYPE_VIDEO:
            on_call_video_state(callInfo, mi, has_error)
        default:
            /* Make gcc happy about enum not handled by switch/case */
            break
        }
    }
    
    if has_error == pj_bool_t(PJ_TRUE.rawValue) {
        var reason: pj_str_t = pj_str(UnsafeMutablePointer<Int8>(mutating: "Media failed"))
        pjsua_call_hangup(callID, 500, &reason, nil)
        fatalError()
    }
    
//    #if PJSUA_HAS_VIDEO
        /* Check if remote has just tried to enable video */
        if callInfo.rem_offerer != 0 && callInfo.rem_vid_cnt != 0 {
            var vid_idx = 0
//            var wid: pjsua_vid_win_id = PJSUA_INVALID_ID.rawValue
            
//            vid_idx = Int(pjsua_call_get_vid_stream_idx(callID))
            
//            if vid_idx >= 0 {
//                // Convert fixed-size C array(Swift treats as tuple) to Swift array.
//                var mediaTuple = callInfo.media
//                let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
//                    let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
//                    let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
//
//                    return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
//                }
//
//                wid = media[vid_idx].stream.vid.win_in
//            }
//
//            print("==Window ID: \(wid)")

            
            
            /* Check if there is active video */
            vid_idx = Int(pjsua_call_get_vid_stream_idx(callID))
            
            if vid_idx == -1 || media[vid_idx].dir == PJMEDIA_DIR_NONE {
                print("Just rejected incoming video offer on call \(callID), use \"vid call enable \(vid_idx)\" or \"vid call add\" to enable video!")
            }
        }
//    #endif
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
