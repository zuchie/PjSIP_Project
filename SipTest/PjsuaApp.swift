//
//  PjsuaApp.swift
//  SipTest
//
//  Created by Zhe Cui on 1/8/18.
//  Copyright © 2018 Zhe Cui. All rights reserved.
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

class PjsuaApp {
    static let shared = PjsuaApp()

    let PJSUA_APP_NO_LIMIT_DURATION: CUnsignedInt = 0x7FFFFFFF
    let PJSUA_APP_NO_NB = -2
    
    var current_acc = pjsua_acc_get_default()
    var call_opt = pjsua_call_setting()

    var current_call: pjsua_call_id = PJSUA_INVALID_ID.rawValue
    var app_config = pjsua_app_config()
    
    /* Call specific data */
    struct app_call_data {
        var timer = pj_timer_entry()
        var ringback_on = pj_bool_t()
        var ring_on = pj_bool_t()
    }
    
    /* Video settings */
    struct app_vid {
        var vid_cnt = CUnsignedInt(0)
        var vcapture_dev = CInt(0)
        var vrender_dev = CInt(0)
        var in_auto_show = pj_bool_t(0)
        var out_auto_transmit = pj_bool_t(0)
    }
    
    /* Pjsua application data */
    struct pjsua_app_config {
        var cfg = pjsua_config()
        var log_cfg = pjsua_logging_config()
        var media_cfg = pjsua_media_config()
        var no_refersub: pj_bool_t = 1
        var ipv6: pj_bool_t = 1
        var enable_qos: pj_bool_t = 1
        var no_tcp: pj_bool_t = 1
        var no_udp: pj_bool_t = 1
        var use_tls: pj_bool_t = 1
        var udp_cfg = pjsua_transport_config()
        var rtp_cfg = pjsua_transport_config()
        var redir_op = pjsip_redirect_op(0)
        
        var acc_cnt: CUnsignedInt = 0
        var acc_cfg = Array(repeating: pjsua_acc_config(), count: Int(0/*PJSUA_MAX_ACC*/))
        
        var buddy_cnt: CUnsignedInt = 0
        var buddy_cfg = Array(repeating: pjsua_buddy_config(), count: Int(0/*PJSUA_MAX_BUDDIES*/))
        
        var call_data = Array(repeating: app_call_data(), count: Int(PJSUA_MAX_CALLS))
        
        var pool: UnsafeMutablePointer<pj_pool_t>!
        
        /* Compatibility with older pjsua */
        
        var codec_cnt: CUnsignedInt = 0
        var codec_arg = Array(repeating: pj_str_t(), count: 32)
        var codec_dis_cnt: CUnsignedInt = 0
        var codec_dis = Array(repeating: pj_str_t(), count: 32)
        var null_audio = pj_bool_t(1)
        
        var tone_count = CUnsignedInt(0)
        var tones = Array(repeating: pjmedia_tone_desc(), count: 32)
        var tone_slots = Array(repeating: pjsua_conf_port_id(), count: 32)
        var auto_answer = CUnsignedInt(0)
        var duration = CUnsignedInt(0)
        
        var mic_level = CFloat(0)
        var speaker_level = CFloat(0)
        
        var capture_dev = CInt(0)
        var playback_dev = CInt(0)
        
        var capture_lat = CUnsignedInt(0)
        var playback_lat = CUnsignedInt(0)
        
        var no_tones = pj_bool_t(0)
        var ringback_slot = CInt(0)
        var ringback_cnt = CInt(0)
        var ringback_port = UnsafeMutablePointer<pjmedia_port>(mutating: nil)
        var ring_slot = CInt(0)
        var ring_cnt = CInt(0)
        var ring_port = UnsafeMutablePointer<pjmedia_port>(mutating: nil)
        
        var vid = app_vid()
        var aud_cnt = CUnsignedInt(0)
    }
    
    private init() {}
    
    /* Add account */
    func cmd_add_account() -> pj_status_t {
        var acc_cfg = pjsua_acc_config()
        var status: pj_status_t
        
        let fullURL = ("sip:6728@siptest.butterflymx.com" as NSString).utf8String
        // Always use "sips" for server
        let uri = ("sips:siptest.butterflymx.com" as NSString).utf8String
        let scheme = ("Digest" as NSString).utf8String
        let realm = ("siptest.butterflymx.com" as NSString).utf8String
        let username = ("6728" as NSString).utf8String
        let password = ("123456" as NSString).utf8String
        
        //        // Bypass password for test use.
        //        if usernameTextField.text! == "6728" {
        //            password = ("123456" as NSString).utf8String!
        //            passwordTextField.text = String(cString: password!)
        //        }
        //
        //        if usernameTextField.text! == "panel_4" {
        //            password = ("123" as NSString).utf8String!
        //            passwordTextField.text = String(cString: password!)
        //        }
        
        pjsua_acc_config_default(&acc_cfg)
        acc_cfg.id = pj_str(UnsafeMutablePointer<Int8>(mutating: fullURL))
        acc_cfg.reg_uri = pj_str(UnsafeMutablePointer<Int8>(mutating: uri))
        acc_cfg.cred_count = 1
        acc_cfg.cred_info.0.scheme = pj_str(UnsafeMutablePointer<Int8>(mutating: scheme))
        acc_cfg.cred_info.0.realm = pj_str(UnsafeMutablePointer<Int8>(mutating: realm))
        acc_cfg.cred_info.0.username = pj_str(UnsafeMutablePointer<Int8>(mutating: username))
        acc_cfg.cred_info.0.data_type = 0
        acc_cfg.cred_info.0.data = pj_str(UnsafeMutablePointer<Int8>(mutating: password))
        
        acc_cfg.rtp_cfg = app_config.rtp_cfg
        app_config_init_video(&acc_cfg)
        
        status = pjsua_acc_add(&acc_cfg, pj_bool_t(PJ_TRUE.rawValue), nil)
        if (status != PJ_SUCCESS.rawValue) {
            //pjsua_perror(THIS_FILE, "Error adding new account", status);
            print("!!!!!Error adding new account!")
        }
        
        return status
    }
    
    func pjsuaStart() {
        var status: pj_bool_t = pj_bool_t(PJ_SUCCESS.rawValue)
        
        status = app_init()
        if (status != PJ_SUCCESS.rawValue) {
            //            char errmsg[PJ_ERR_MSG_SIZE]
            //            pj_strerror(status, errmsg, sizeof(errmsg))
            //pjsua_app_destroy();
            fatalError()
        }
        
        status = app_run(pj_bool_t(PJ_TRUE.rawValue))
        if (status != PJ_SUCCESS.rawValue) {
            //            char errmsg[PJ_ERR_MSG_SIZE]
            //            pj_strerror(status, errmsg, sizeof(errmsg))
            fatalError()
        }
        
        _ = cmd_add_account()
        //pjsua_app_destroy();
    }
    
    
    //static var app_cfg = pjsua_app_cfg_t()
    
    //    /**
    //     * This structure contains the configuration of application.
    //     */
    //    struct pjsua_app_cfg_t {
    //        /**
    //         * This will enable application to supply customize configuration other than
    //         * the basic configuration provided by pjsua.
    //         */
    //        void (*on_config_init)(pjsua_app_config *cfg);
    //    }
    
    
    
    
    /* Set default config. */
    func default_config() -> pjsua_app_config {
        let tmp = Array(repeating: CChar(), count: 80)
        var cfg = app_config
        
        pjsua_config_default(&cfg.cfg)
        
        print("PJSUA \(pj_get_version().pointee) \(String(cString: pj_get_sys_info().pointee.info.ptr))")
        
        pj_strdup2_with_null(app_config.pool, &cfg.cfg.user_agent, tmp)
        
        pjsua_logging_config_default(&cfg.log_cfg)
        pjsua_media_config_default(&cfg.media_cfg)
        pjsua_transport_config_default(&cfg.udp_cfg)
        cfg.udp_cfg.port = 5060
        pjsua_transport_config_default(&cfg.rtp_cfg)
        cfg.rtp_cfg.port = 4000
        cfg.redir_op = PJSIP_REDIRECT_ACCEPT_REPLACE
        cfg.duration = PJSUA_APP_NO_LIMIT_DURATION
        cfg.mic_level = 1.0
        cfg.speaker_level = 1.0
        cfg.capture_dev = PJSUA_INVALID_ID.rawValue
        cfg.playback_dev = PJSUA_INVALID_ID.rawValue
        cfg.capture_lat = CUnsignedInt(PJMEDIA_SND_DEFAULT_REC_LATENCY)
        cfg.playback_lat = CUnsignedInt(PJMEDIA_SND_DEFAULT_PLAY_LATENCY)
        cfg.ringback_slot = PJSUA_INVALID_ID.rawValue
        cfg.ring_slot = PJSUA_INVALID_ID.rawValue
        
        for i in 0..<cfg.acc_cfg.count {
            pjsua_acc_config_default(&cfg.acc_cfg[i])
            // Pete, added for test, do not retry registration.
            cfg.acc_cfg[i].reg_retry_interval = 0
        }
        
        cfg.vid.in_auto_show = pj_bool_t(PJ_TRUE.rawValue)
        cfg.vid.out_auto_transmit = pj_bool_t(PJ_TRUE.rawValue)
        cfg.vid.vid_cnt = 1
        cfg.vid.vcapture_dev = PJMEDIA_VID_DEFAULT_CAPTURE_DEV.rawValue
        cfg.vid.vrender_dev = PJMEDIA_VID_DEFAULT_RENDER_DEV.rawValue
        cfg.aud_cnt = 1
        
        // Pete, added for test
        cfg.use_tls = pj_bool_t(PJ_TRUE.rawValue)
        cfg.cfg.outbound_proxy_cnt = 1
        cfg.cfg.outbound_proxy.0 = pj_str(UnsafeMutablePointer<Int8>(mutating: "sips:siptest.butterflymx.com:5061"))
        cfg.udp_cfg.port = 5061
        
        return cfg
    }
    
    //#ifdef PJSUA_HAS_VIDEO
    func app_config_init_video(_ acc_cfg: inout pjsua_acc_config) {
        acc_cfg.vid_in_auto_show = app_config.vid.in_auto_show
        acc_cfg.vid_out_auto_transmit = app_config.vid.out_auto_transmit
        /* Note that normally GUI application will prefer a borderless
         * window.
         */
        acc_cfg.vid_wnd_flags = PJMEDIA_VID_DEV_WND_BORDER.rawValue | PJMEDIA_VID_DEV_WND_RESIZABLE.rawValue
        acc_cfg.vid_cap_dev = app_config.vid.vcapture_dev
        acc_cfg.vid_rend_dev = app_config.vid.vrender_dev
    }
    
    func app_run(_ wait_telnet_cli: pj_bool_t) -> pj_status_t {
        //    pj_thread_t *stdout_refresh_thread = NULL;
        var status: pj_status_t
        
        //    /* Start console refresh thread */
        //    if (stdout_refresh > 0) {
        //        pj_thread_create(app_config.pool, "stdout", &stdout_refresh_proc,
        //                         NULL, 0, 0, &stdout_refresh_thread);
        //    }
        
        status = pjsua_start()
        if (status != PJ_SUCCESS.rawValue) {
            fatalError()
        }
        
        // Enum audio codecs
        var count: CUnsignedInt = 9
        let codecs = Array(repeating: pjsua_codec_info(), count: Int(count))
        
        if (pjsua_enum_codecs(UnsafeMutablePointer(mutating: codecs), &count) == Int32(PJ_SUCCESS.rawValue)) {
            print("List of codecs:")
            
            for (_, codec) in codecs.enumerated() {
                print("ID: \(String(cString: codec.codec_id.ptr)), priority: \(Int(codec.priority))")
            }
        }
        
        // Set codec priority
        print("Reset codec priorities.")
        
        var codec: pj_str_t = pj_str_t()
        
        pjsua_codec_set_priority(pj_cstr(&codec, "opus/48000/2"), pj_uint8_t(PJMEDIA_CODEC_PRIO_HIGHEST.rawValue))
        
        pjsua_codec_set_priority(pj_cstr(&codec, "speex/16000/1"), pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
        pjsua_codec_set_priority(pj_cstr(&codec, "speex/8000/1"), pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
        pjsua_codec_set_priority(pj_cstr(&codec, "speex/32000/1"), pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
        pjsua_codec_set_priority(pj_cstr(&codec, "iLBC/8000/1"), pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
        pjsua_codec_set_priority(pj_cstr(&codec, "GSM/8000/1"), pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
        pjsua_codec_set_priority(pj_cstr(&codec, "PCMU/8000/1"), pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
        pjsua_codec_set_priority(pj_cstr(&codec, "PCMA/8000/1"), pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
        pjsua_codec_set_priority(pj_cstr(&codec, "G722/16000/1"), pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
        
        if (pjsua_enum_codecs(UnsafeMutablePointer(mutating: codecs), &count) == Int32(PJ_SUCCESS.rawValue)) {
            print("List of codecs after reset priorities:")
            
            for (_, codec) in codecs.enumerated() {
                print("ID: \(String(cString: codec.codec_id.ptr)), priority: \(Int(codec.priority))")
            }
        }
        
        // Enum Video codecs
        var videoCodecsCount: CUnsignedInt = 2
        let videoCodecs = Array(repeating: pjsua_codec_info(), count: Int(videoCodecsCount))
        
        if (pjsua_vid_enum_codecs(UnsafeMutablePointer(mutating: videoCodecs), &videoCodecsCount) == Int32(PJ_SUCCESS.rawValue)) {
            print("List of video codecs:")
            
            for i in 0..<videoCodecsCount {
                print("ID: \(String(cString: videoCodecs[Int(i)].codec_id.ptr)), priority: \(Int(videoCodecs[Int(i)].priority))")
            }
            
            //            for (_, codec) in videoCodecs.enumerated() {
            //                print("ID: \(String(cString: codec.codec_id.ptr)), priority: \(Int(codec.priority))")
            //            }
        }
        
        // Set video codec priority
        print("Reset video codec priorities.")
        
        var videoCodec: pj_str_t = pj_str_t()
        
        pjsua_vid_codec_set_priority(pj_cstr(&videoCodec, "H264/97"), pj_uint8_t(PJMEDIA_CODEC_PRIO_HIGHEST.rawValue))
        //pjsua_vid_codec_set_priority(pj_cstr(&videoCodec, "VP8/90000"), pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
        
        if (pjsua_vid_enum_codecs(UnsafeMutablePointer(mutating: videoCodecs), &videoCodecsCount) == Int32(PJ_SUCCESS.rawValue)) {
            print("List of video codecs after reset priorities:")
            
            for i in 0..<videoCodecsCount {
                print("ID: \(String(cString: videoCodecs[Int(i)].codec_id.ptr)), priority: \(Int(videoCodecs[Int(i)].priority))")
            }
            
            //            for (_, codec) in videoCodecs.enumerated() {
            //                print("ID: \(String(cString: codec.codec_id.ptr)), priority: \(Int(codec.priority))")
            //            }
        }
        
        return status
    }
    
    func app_init() -> pj_status_t {
        var transport_id: pjsua_transport_id = -1
        var tcp_cfg = pjsua_transport_config()
        var tmp_pool: UnsafeMutablePointer<pj_pool_t>
        var status: pj_status_t = pj_status_t(PJ_SUCCESS.rawValue)
        
        /** Create pjsua **/
        status = pjsua_create()
        if status != PJ_SUCCESS.rawValue {
            return status
        }
        
        /* Create pool for application */
        app_config.pool = pjsua_pool_create("pjsua-app", 1000, 1000)
        
        tmp_pool = pjsua_pool_create("tmp-pjsua", 1000, 1000)
        
        app_config = default_config()
        
        /* Initialize application callbacks */
        app_config.cfg.cb.on_call_state = on_call_state
        app_config.cfg.cb.on_call_media_state = on_call_media_state
        app_config.cfg.cb.on_incoming_call = on_incoming_call
        app_config.cfg.cb.on_reg_state = on_reg_state
        app_config.cfg.cb.on_transport_state = on_transport_state
        app_config.cfg.cb.on_call_media_event = on_call_media_event
        
        /* Set sound device latency */
        if (app_config.capture_lat > 0) {
            app_config.media_cfg.snd_rec_latency = app_config.capture_lat
        }
        
        if (app_config.playback_lat != 0) {
            app_config.media_cfg.snd_play_latency = app_config.playback_lat
        }
        
        //        if (app_cfg.on_config_init) {
        //            (*app_cfg.on_config_init)(&app_config)
        //        }
        
        // Pete
        app_config.cfg.outbound_proxy_cnt = 1;
        app_config.cfg.outbound_proxy.0 = pj_str(UnsafeMutablePointer<Int8>(mutating: "sips:siptest.butterflymx.com:5061"))
        
        /* Initialize pjsua */
        status = pjsua_init(&(app_config.cfg), &(app_config.log_cfg), &(app_config.media_cfg))
        
        if (status != PJ_SUCCESS.rawValue) {
            pj_pool_release(tmp_pool)
            return status
        }
        
        
        //#if defined(PJSIP_HAS_TLS_TRANSPORT) && PJSIP_HAS_TLS_TRANSPORT!=0
        /* Add TLS transport when application wants one */
        if (app_config.use_tls != 0) {
            
            var acc_id = pjsua_acc_id()
            
            /* Copy the QoS settings */
            tcp_cfg.tls_setting.qos_type = tcp_cfg.qos_type
            tcp_cfg.tls_setting.qos_params = tcp_cfg.qos_params
            
            /* Set TLS port as TCP port+1 */
            tcp_cfg.port += 1
            status = pjsua_transport_create(PJSIP_TRANSPORT_TLS, &tcp_cfg, &transport_id)
            tcp_cfg.port -= 1
            if (status != PJ_SUCCESS.rawValue) {
                pj_pool_release(tmp_pool)
                fatalError()
            }
            
//            /* Add local account */
//            pjsua_acc_add_local(transport_id, pj_bool_t(PJ_FALSE.rawValue), &acc_id)
//
//            /* Adjust local account config based on pjsua app config */
//            do {
//                var acc_cfg = pjsua_acc_config()
//                pjsua_acc_get_config(acc_id, tmp_pool, &acc_cfg)
//
//                app_config_init_video(&acc_cfg)
//                acc_cfg.rtp_cfg = app_config.rtp_cfg
//                pjsua_acc_modify(acc_id, &acc_cfg)
//            }
//
//            pjsua_acc_set_online_status(acc_id, pj_bool_t(PJ_TRUE.rawValue))
        }
        
        
        
        if (transport_id == -1) {
            print("Error: no transport is configured")
            status = -1
            pj_pool_release(tmp_pool)
            fatalError()
        }
        
//        /* Optionally disable some codec */
//        for i in 0..<Int(app_config.codec_dis_cnt) {
//            pjsua_codec_set_priority(&app_config.codec_dis[i], pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
//            //#if PJSUA_HAS_VIDEO
//            pjsua_vid_codec_set_priority(&app_config.codec_dis[i], pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
//            //#endif
//        }
//
//
//        /* Optionally set codec orders */
//        for i in 0..<Int(app_config.codec_cnt) {
//            pjsua_codec_set_priority(&app_config.codec_arg[i], (pj_uint8_t)(Int(PJMEDIA_CODEC_PRIO_NORMAL.rawValue)+i+9))
//            //#if PJSUA_HAS_VIDEO
//            pjsua_vid_codec_set_priority(&app_config.codec_arg[i], (pj_uint8_t)(Int(PJMEDIA_CODEC_PRIO_NORMAL.rawValue)+i+9))
//            //#endif
//        }
        
        //        /* Use null sound device? */
        //        //    #ifndef STEREO_DEMO
        //        if (app_config.null_audio != 0) {
        //            status = pjsua_set_null_snd_dev()
        //            if (status != PJ_SUCCESS.rawValue) {
        //                return status
        //            }
        //        }
        //        //#endif
        
        if (app_config.capture_dev != PJSUA_INVALID_ID.rawValue ||
            app_config.playback_dev != PJSUA_INVALID_ID.rawValue)
        {
            status = pjsua_set_snd_dev(app_config.capture_dev,
                                       app_config.playback_dev)
            if (status != PJ_SUCCESS.rawValue) {
                fatalError()
            }
        }
        
        /* Init call setting */
        pjsua_call_setting_default(&call_opt)
        call_opt.aud_cnt = app_config.aud_cnt
        call_opt.vid_cnt = app_config.vid.vid_cnt
        
        pj_pool_release(tmp_pool)
        return pj_status_t(PJ_SUCCESS.rawValue)
    }
    
    let on_reg_state: @convention(c) (pjsua_acc_id) -> Void = { accountID in
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
    
//    func on_reg_state(accountID: pjsua_acc_id) {
//        var status = pj_status_t()
//        var info = pjsua_acc_info()
//
//        status = pjsua_acc_get_info(accountID, &info)
//
//        if status != PJ_SUCCESS.rawValue {
//            print("Error registration status: \(status)")
//
//            return
//        }
//
//        DispatchQueue.main.async {
//            NotificationCenter.default.post(name: SIPNotification.registrationState.notification, object: nil, userInfo: ["accountID" : accountID, "statusText" : String(cString: info.status_text.ptr), "status" : info.status])
//        }
//    }
    
    /*
     * Find next call when current call is disconnected or when user
     * press ']'
     */
    func find_next_call() -> pj_bool_t {
        var max: Int
        
        max = Int(pjsua_call_get_max_count())
        for i in Int(current_call + 1)..<max {
            if pjsua_call_is_active(pjsua_call_id(i)) == pj_bool_t(PJ_TRUE.rawValue) {
                current_call = pjsua_call_id(i)
                return pj_bool_t(PJ_TRUE.rawValue)
            }
        }
        
        for i in 0..<current_call {
            if (pjsua_call_is_active(i)) == pj_bool_t(PJ_TRUE.rawValue) {
                current_call = i
                return pj_bool_t(PJ_TRUE.rawValue)
            }
        }
        
        current_call = PJSUA_INVALID_ID.rawValue
        
        return pj_bool_t(PJ_FALSE.rawValue)
    }
    
    let on_call_state: @convention(c) (pjsua_call_id, UnsafeMutablePointer<pjsip_event>?) -> Void = { call_id, e in
        
        var call_info = pjsua_call_info()
        
        //PJ_UNUSED_ARG(e)
        
        pjsua_call_get_info(call_id, &call_info)
        
        if (call_info.state == PJSIP_INV_STATE_DISCONNECTED) {
            
            /* Stop all ringback for this call */
            //ring_stop(call_id)
            
            
            print("Call \(call_id) is DISCONNECTED [reason=\(call_info.last_status) \(call_info.last_status_text.ptr)]")
            
            if (call_id == PjsuaApp.shared.current_call) {
                _ = PjsuaApp.shared.find_next_call()
            }
            
            /* Dump media state upon disconnected */
            print("Call \(call_id) disconnected, dumping media stats..")
            
        } else {
            if (call_info.state == PJSIP_INV_STATE_EARLY) {
                
                if PjsuaApp.shared.current_call == PJSUA_INVALID_ID.rawValue {
                    PjsuaApp.shared.current_call = call_id
                }
            }
            
            //    id argument = @{
            //        @"call_id"  : @(call_id),
            //        @"state"    : @(ci.state)
            //    };
            //
            //    dispatch_async(dispatch_get_main_queue(), ^{
            //        [[NSNotificationCenter defaultCenter] postNotificationName:@"SIPCallStatusChangedNotification" object:nil userInfo:argument];
            //    });
        }
    }
    
    
    /* Process audio media state. "mi" is the media index. */
    func on_call_audio_state(_ ci: pjsua_call_info, _ mi: Int,
                             _ has_error: pj_bool_t) {
        
        /* Stop ringback */
        //ring_stop(ci.id)
        
        /* Connect ports appropriately when media status is ACTIVE or REMOTE HOLD,
         * otherwise we should NOT connect the ports.
         */
        var mediaTuple = ci.media
        let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
            let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
            let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
            
            return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
        }
        
        if (media[mi].status == PJSUA_CALL_MEDIA_ACTIVE || media[mi].status == PJSUA_CALL_MEDIA_REMOTE_HOLD) {
            let connect_sound: pj_bool_t  = pj_bool_t(PJ_TRUE.rawValue)
            let disconnect_mic: pj_bool_t  = pj_bool_t(PJ_FALSE.rawValue)
            var call_conf_slot: pjsua_conf_port_id
            
            call_conf_slot = media[mi].stream.aud.conf_slot
            
            /* Otherwise connect to sound device */
            if connect_sound == pj_bool_t(PJ_TRUE.rawValue) {
                pjsua_conf_connect(call_conf_slot, 0)
                
                if disconnect_mic == pj_bool_t(PJ_FALSE.rawValue) {
                    pjsua_conf_connect(0, call_conf_slot)
                }
            }
        }
    }
    
    /* Process video media state. "mi" is the media index. */
    func on_call_video_state(_ ci: pjsua_call_info, _ mi: Int, _ has_error: pj_bool_t) {
        if ci.media_status != PJSUA_CALL_MEDIA_ACTIVE { return }
        
        var mediaTuple = ci.media
        let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
            let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
            let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
            
            return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
        }
        
        arrange_window(media[mi].stream.vid.win_in)
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
    
    /*
     * Callback on media state changed event.
     * The action may connect the call to sound device, to file, or
     * to loop the call.
     */
    let on_call_media_state: @convention(c) (pjsua_call_id) -> Void = { call_id in
        var call_info = pjsua_call_info()
        let has_error = pj_bool_t(PJ_FALSE.rawValue)
        
        pjsua_call_get_info(call_id, &call_info)
        
        for mi in 0..<Int(call_info.media_cnt) {
            var mediaTuple = call_info.media
            let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
                let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
                let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
                
                return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
            }
            
            switch media[Int(mi)].type {
            case PJMEDIA_TYPE_AUDIO:
                if (call_info.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
                    PjsuaApp.shared.on_call_audio_state(call_info, mi, has_error)
                }
            case PJMEDIA_TYPE_VIDEO:
                PjsuaApp.shared.on_call_video_state(call_info, mi, has_error)
            default:
                break
            }
        }
        
        if has_error == pj_bool_t(PJ_TRUE.rawValue) {
            var reason = pj_str(UnsafeMutablePointer<Int8>(mutating: "Media failed"))
            pjsua_call_hangup(call_id, 500, &reason, nil)
        }
        
        //#if PJSUA_HAS_VIDEO
        /* Check if remote has just tried to enable video */
        if call_info.rem_offerer != 0 && call_info.rem_vid_cnt != 0 {
            var vid_idx: Int
            
            /* Check if there is active video */
            vid_idx = Int(pjsua_call_get_vid_stream_idx(call_id))
            
            // Convert fixed-size C array(Swift treats as tuple) to Swift array.
            var mediaTuple = call_info.media
            let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
                let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
                let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
                
                return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
            }
            
            //wid = media[vid_idx].stream.vid.win_in
            if (vid_idx == -1 || media[vid_idx].dir == PJMEDIA_DIR_NONE) {
                print("Just rejected incoming video offer on call \(call_id), use \"vid call enable \(vid_idx)\" or \"vid call add\" to enable video!")
            }
        }
        //#endif
    }
    
    func ring_start(_ call_id: pjsua_call_id) {
        if (app_config.no_tones) == pj_bool_t(PJ_TRUE.rawValue) { return }
        
        if (app_config.call_data[Int(call_id)].ring_on == pj_bool_t(PJ_TRUE.rawValue)) { return }
        
        app_config.call_data[Int(call_id)].ring_on = pj_bool_t(PJ_TRUE.rawValue)
        
        if (app_config.ring_cnt + 1 == 1), app_config.ring_slot != PJSUA_INVALID_ID.rawValue {
            pjsua_conf_connect(app_config.ring_slot, 0)
        }
    }
    
    func ring_stop(_ call_id: pjsua_call_id) {
        if app_config.no_tones == pj_bool_t(PJ_TRUE.rawValue) { return }
        
        if app_config.call_data[Int(call_id)].ringback_on == pj_bool_t(PJ_TRUE.rawValue) {
            app_config.call_data[Int(call_id)].ringback_on = pj_bool_t(PJ_FALSE.rawValue)
            
            assert(app_config.ringback_cnt > 0)
            if app_config.ringback_cnt - 1 == 0, app_config.ringback_slot != PJSUA_INVALID_ID.rawValue {
                pjsua_conf_disconnect(app_config.ringback_slot, 0)
                pjmedia_tonegen_rewind(app_config.ringback_port)
            }
        }
        
        if app_config.call_data[Int(call_id)].ring_on == pj_bool_t(PJ_TRUE.rawValue) {
            app_config.call_data[Int(call_id)].ring_on = pj_bool_t(PJ_FALSE.rawValue)
            
            assert(app_config.ring_cnt > 0)
            if app_config.ring_cnt - 1 == 0, app_config.ring_slot != PJSUA_INVALID_ID.rawValue {
                pjsua_conf_disconnect(app_config.ring_slot, 0)
                pjmedia_tonegen_rewind(app_config.ring_port)
            }
        }
    }
    
    let on_incoming_call: @convention(c) (pjsua_acc_id, pjsua_call_id, UnsafeMutablePointer<pjsip_rx_data>?) -> Void = { acc_id, call_id, rdata in
        var call_info = pjsua_call_info()
        
        //    PJ_UNUSED_ARG(acc_id);
        //    PJ_UNUSED_ARG(rdata);
        
        pjsua_call_get_info(call_id, &call_info)
        
        if PjsuaApp.shared.current_call == PJSUA_INVALID_ID.rawValue {
            PjsuaApp.shared.current_call = call_id
        }
        
        /* Start ringback */
        //ring_start(call_id)
        
        //    if (app_config.auto_answer > 0) {
        var opt = pjsua_call_setting()
        
        pjsua_call_setting_default(&opt)
        opt.aud_cnt = PjsuaApp.shared.app_config.aud_cnt
        opt.vid_cnt = PjsuaApp.shared.app_config.vid.vid_cnt
        
        pjsua_call_answer2(call_id, &opt, 200/*app_config.auto_answer*/, nil, nil)
        //    }
        
        if (PjsuaApp.shared.app_config.auto_answer < 200) {
            
            //#if PJSUA_HAS_VIDEO
            if call_info.rem_offerer == pj_bool_t(PJ_TRUE.rawValue), call_info.rem_vid_cnt != 0 {
                print("To \((PjsuaApp.shared.app_config.vid.vid_cnt != 0 ? "reject" : "accept")) the video, type \"vid \((PjsuaApp.shared.app_config.vid.vid_cnt != 0 ? "disable" : "enable"))\" first, before answering the call!")
            }
            //#endif
        }
        
        //    dispatch_async(dispatch_get_main_queue(), ^{
        //        [[NSNotificationCenter defaultCenter] postNotificationName:@"SIPIncomingCallNotification" object:nil userInfo:argument];
        //    });
        
    }
    
    /* Callback on media events */
    let on_call_media_event: @convention(c) (pjsua_call_id, CUnsignedInt, UnsafeMutablePointer<pjmedia_event>?) -> Void = { call_id, med_idx, event in
        var event_name = Array(repeating: CChar(), count: 5)
        
        print("Event \(pjmedia_fourcc_name(event!.pointee.type.rawValue, &event_name))")
        
        //    #if PJSUA_HAS_VIDEO
        if (event!.pointee.type == PJMEDIA_EVENT_FMT_CHANGED) {
            /* Adjust renderer window size to original video size */
            var ci = pjsua_call_info()
            
            pjsua_call_get_info(call_id, &ci)
            
            var mediaTuple = ci.media
            let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
                let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
                let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
                
                return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
            }
            
            if ((media[Int(med_idx)].type == PJMEDIA_TYPE_VIDEO) &&
                ((media[Int(med_idx)].dir.rawValue & PJMEDIA_DIR_DECODING.rawValue) != 0))
            {
                var wid: pjsua_vid_win_id
                var size: pjmedia_rect_size
                var win_info = pjsua_vid_win_info()
                
                wid = media[Int(med_idx)].stream.vid.win_in
                pjsua_vid_win_get_info(wid, &win_info)
                
                size = event!.pointee.data.fmt_changed.new_fmt.det.vid.size
                if (size.w != win_info.size.w || size.h != win_info.size.h) {
                    pjsua_vid_win_set_size(wid, &size)
                    
                    /* Re-arrange video windows */
                    PjsuaApp.shared.arrange_window(PJSUA_INVALID_ID.rawValue)
                }
            }
        }
        //    #endif
    }
    
    /*
     * Transport status notification
     */
    let on_transport_state: @convention(c) (UnsafeMutablePointer<pjsip_transport>?, pjsip_transport_state, UnsafePointer<pjsip_transport_state_info>?) -> Void = { tp, state, info in
        let tp = tp!.pointee
        let info = info!.pointee
        let host_port = String(cString: (tp.remote_name.host.ptr))
        
        
        switch (state) {
        case PJSIP_TP_STATE_CONNECTED:
            print("SIP \(tp.type_name) transport is connected to \(host_port)")
        case PJSIP_TP_STATE_DISCONNECTED:
            print("SIP \(tp.type_name) transport is disconnected from \(host_port)")
        default:
            break
        }
        
        //    #if defined(PJSIP_HAS_TLS_TRANSPORT) && PJSIP_HAS_TLS_TRANSPORT!=0
        
        if (String(cString: tp.type_name) != "tls" && (info.ext_info != nil) &&
            (state == PJSIP_TP_STATE_CONNECTED ||
                (info.ext_info.load(as: pjsip_tls_state_info.self)).ssl_sock_info.pointee.verify_status != PJ_SUCCESS.rawValue))
        {
            let tls_info = info.ext_info.load(as: pjsip_tls_state_info.self)
            let ssl_sock_info = tls_info.ssl_sock_info.pointee
            var buf: [CChar] = Array(repeating: CChar(), count: 2048)
            //            const char *verif_msgs[32];
            //            unsigned verif_msg_cnt;
            
            /* Dump server TLS cipher */
            print("TLS cipher used: 0x\(ssl_sock_info.cipher)/\(pj_ssl_cipher_name(ssl_sock_info.cipher))")
            
            /* Dump server TLS certificate */
            pj_ssl_cert_info_dump(ssl_sock_info.remote_cert_info, "  ", &buf, 2048)
            print("TLS cert info of \(host_port): \(buf)")
            
            //            /* Dump server TLS certificate verification result */
            //            verif_msg_cnt = PJ_ARRAY_SIZE(verif_msgs);
            //            pj_ssl_cert_get_verify_status_strings(ssl_sock_info->verify_status,
            //                                                  verif_msgs, &verif_msg_cnt);
            //            PJ_LOG(3,(THIS_FILE, "TLS cert verification result of %s : %s",
            //                      host_port,
            //                      (verif_msg_cnt == 1? verif_msgs[0]:"")));
            //            if (verif_msg_cnt > 1) {
            //                unsigned i;
            //                for (i = 0; i < verif_msg_cnt; ++i)
            //                PJ_LOG(3,(THIS_FILE, "- %s", verif_msgs[i]));
            //            }
            //
            //            if (ssl_sock_info->verify_status &&
            //                !app_config.udp_cfg.tls_setting.verify_server)
            //            {
            //                PJ_LOG(3,(THIS_FILE, "PJSUA is configured to ignore TLS cert "
            //                    "verification errors"));
            //            }
        }
        
        //    #endif
        
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
    
}
