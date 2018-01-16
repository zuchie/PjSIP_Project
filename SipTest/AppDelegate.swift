//
//  AppDelegate.swift
//  SipTest
//
//  Created by Zhe Cui on 12/17/17.
//  Copyright © 2017 Zhe Cui. All rights reserved.
//

import UIKit
import PushKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate {

    var window: UIWindow?
    var captureDeviceID: Int32 = -1000
    var playbackDeviceID: Int32 = -1000
    var voipRegistry: PKPushRegistry!
        
    class var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    var providerDelegate: ProviderDelegate!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Register VoIP
        self.voipRegistration()
        
        // CallKit and PJSUA configure
        providerDelegate = ProviderDelegate()
        
#if OLD_APP
        var status: pj_status_t

        status = pjsua_create()
        if status != PJ_SUCCESS.rawValue {
            print("Error creating pjsua, status: \(status)")
            return false
        }

        var pjsuaConfig = pjsua_config()
        var pjsuaMediaConfig = pjsua_media_config()
        var pjsuaLoggingConfig = pjsua_logging_config()

        pjsua_config_default(&pjsuaConfig)

        pjsuaConfig.cb.on_incoming_call = onIncomingCall
        pjsuaConfig.cb.on_call_media_state = onCallMediaState
        pjsuaConfig.cb.on_call_state = onCallState
        pjsuaConfig.cb.on_reg_state = onRegState

        // Have to add proxy in order to use "sip" instead of "sips" for full URI
        pjsuaConfig.outbound_proxy_cnt = 1;
        pjsuaConfig.outbound_proxy.0 = pj_str(UnsafeMutablePointer<Int8>(mutating: ("sips:siptest.butterflymx.com" as NSString).utf8String))


        // Media config
        pjsua_media_config_default(&pjsuaMediaConfig)
        pjsuaMediaConfig.clock_rate = 16000
        pjsuaMediaConfig.snd_clock_rate = 16000
        pjsuaMediaConfig.ec_tail_len = 0

        // Logging config
        pjsua_logging_config_default(&pjsuaLoggingConfig)
#if DEBUG
        pjsuaLoggingConfig.msg_logging = pj_bool_t(PJ_TRUE.rawValue)
        pjsuaLoggingConfig.console_level = 5
        pjsuaLoggingConfig.level = 5
#else
        pjsuaLoggingConfig.msg_logging = pj_bool_t(PJ_FALSE.rawValue)
        pjsuaLoggingConfig.console_level = 0
        pjsuaLoggingConfig.level = 0
#endif

        // Init
        status = pjsua_init(&pjsuaConfig, &pjsuaLoggingConfig, &pjsuaMediaConfig)

        if status != PJ_SUCCESS.rawValue {
            print("Error initializing pjsua, status: \(status)")
            return false
        }

        // Transport config
        var pjsuaTransportConfig = pjsua_transport_config()

        pjsua_transport_config_default(&pjsuaTransportConfig)

        /*
        status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &pjsuaTransportConfig, nil)
        if status != PJ_SUCCESS.rawValue {
            print("Error creating UDP transport, status: \(status)")
            return false
        }
        */
        //let transportID: pjsua_transport_id = -1

        pjsuaTransportConfig.port = 5061
        status = pjsua_transport_create(PJSIP_TRANSPORT_TLS, &pjsuaTransportConfig, nil)

        if status != PJ_SUCCESS.rawValue {
            print("Error creating TLS transport, status: \(status)")
            return false
        }

        status = pjsua_start()
        if status != PJ_SUCCESS.rawValue {
            print("Error starting pjsua, status: \(status)")
            return false
        }
    
//        // Config video codecs
//        var codec_id: pj_str_t = pj_str_t(ptr: UnsafeMutablePointer<Int8>(mutating: "H264"), slen: 4)
//        var cp = pjmedia_vid_codec_param()
//
//        status = pjsua_vid_codec_get_param(&codec_id, &cp)
//        if status == PJ_SUCCESS.rawValue {
//            // Size
//            cp.enc_fmt.det.vid.size.w = 1280
//            cp.enc_fmt.det.vid.size.h = 720
//            // Framerate
//            cp.enc_fmt.det.vid.fps.num = 30
//            cp.enc_fmt.det.vid.fps.denum = 1
//            // Bitrate
//            cp.enc_fmt.det.vid.avg_bps = 512000
//            cp.enc_fmt.det.vid.max_bps = 1024000
//            status = pjsua_vid_codec_set_param(&codec_id, &cp)
//        }
//
//        if status != PJ_SUCCESS.rawValue {
//            fatalError()
//        }
    
//        /* Can receive up to 1280×720 @30fps */
//        cp.dec_fmtp.param[0].name = pj_str("profile-level-id")
//        /* Set the profile level to "1f", which means level 3.1 */
//        cp.dec_fmtp.param[0].val = pj_str("xxxx1f")
    
        // Get sound devices
        status = pjsua_get_snd_dev(&captureDeviceID, &playbackDeviceID)
        if status != PJ_SUCCESS.rawValue {
            print("Error get sound dev IDs, status: \(status)")
            fatalError()
        }

        // Disconnect sound devices
        pjsua_set_no_snd_dev()
    
#else
        PjsuaApp.shared.pjsuaStart()
#endif // #if OLD_APP
        
        return true
    }
    
    func voipRegistration() {
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
    }

    // Handle incoming pushes
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        print("==Push registry, token: \(pushCredentials.token)")
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("==Push registry 1")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

#if OLD_APP
    
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
//                    videoView.bounds = CGRect(x: 0, y: 0, width: topVC.view.bounds.size.width, height: topVC.view.bounds.size.height * 1.0 * topVC.view.bounds.size.width / videoView.bounds.size.width)
                    videoView.bounds = CGRect(x: 0, y: 0, width: topVC.view.bounds.size.width, height: topVC.view.bounds.size.height / 2.0)

                    /* Center it horizontally */
                    videoView.center = CGPoint(x: topVC.view.bounds.size.width / 2.0, y: videoView.bounds.size.height / 2.0)
                    //                    // Show window
                    //                    print("i: \(i)")
                    //                    pjsua_vid_win_set_show(i, pj_bool_t(PJ_TRUE.rawValue))
                } else {
                    videoView.bounds = CGRect(x: 0, y: 0, width: topVC.view.bounds.width / 8.0, height: topVC.view.bounds.height / 4)

//                    videoView.bounds.size.width = topVC.view.bounds.size.width / 2.0
//                    videoView.bounds.size.height = topVC.view.bounds.size.height / 2.0

                    /* Preview window, move it to the bottom */
                    videoView.center = CGPoint(x: topVC.view.bounds.width / 2.0, y: topVC.view.bounds.height - videoView.bounds.height / 2.0)
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
        var reason: pj_str_t = pj_str(UnsafeMutablePointer<Int8>(mutating: ("Media failed" as NSString).utf8String))
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
    
#endif // #if OLD_APP
