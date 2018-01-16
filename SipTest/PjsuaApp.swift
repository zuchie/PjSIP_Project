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
    
    var current_acc = pjsua_acc_get_default()
    var call_opt = pjsua_call_setting()

    var current_call: pjsua_call_id = PJSUA_INVALID_ID.rawValue
    var media_index: UInt32 = 0
    var app_config = pjsua_app_config()
    
    /* Call specific data */
    struct app_call_data {
        var timer = pj_timer_entry()
        var ringback_on = pj_bool_t()
        var ring_on = pj_bool_t()
    }
    
    /* Video settings */
    struct app_vid {
        var vid_cnt: UInt32 = 1
        var vcapture_dev: Int32 = PJMEDIA_VID_DEFAULT_CAPTURE_DEV.rawValue
        var vrender_dev: Int32 = PJMEDIA_VID_DEFAULT_RENDER_DEV.rawValue
        var in_auto_show: pj_bool_t = 1
        var out_auto_transmit: pj_bool_t = 1
    }
    
    /* Pjsua application data */
    struct pjsua_app_config {
        var cfg = pjsua_config()
        var log_cfg = pjsua_logging_config()
        var media_cfg = pjsua_media_config()
        var ipv6: pj_bool_t = 1
        var enable_qos: pj_bool_t = 1
        var no_tcp: pj_bool_t = 1
        var no_udp: pj_bool_t = 1
        var use_tls: pj_bool_t = 1 // Enable SSL
        var udp_cfg = pjsua_transport_config()
        var rtp_cfg = pjsua_transport_config()
        
        var call_data = Array(repeating: app_call_data(), count: Int(PJSUA_MAX_CALLS))
        
        /* Compatibility with older pjsua */
        var null_audio: pj_bool_t = 0
        
        var auto_answer: UInt32 = 200 // Call answer code
        var duration: UInt32 = 0x7FFFFFFF // No limit duration
        
        var mic_level: Float = 1.0
        var speaker_level: Float = 1.0
        
        var capture_dev: Int32 = PJSUA_INVALID_ID.rawValue
        var playback_dev: Int32 = PJSUA_INVALID_ID.rawValue
        
        var capture_lat: UInt32 = UInt32(PJMEDIA_SND_DEFAULT_REC_LATENCY)
        var playback_lat: UInt32 = UInt32(PJMEDIA_SND_DEFAULT_PLAY_LATENCY)
        
        var no_tones: pj_bool_t = 0
        var ringback_slot: Int32 = PJSUA_INVALID_ID.rawValue
        var ringback_cnt: Int32 = 0
        var ringback_port = UnsafeMutablePointer<pjmedia_port>(mutating: nil)
        var ring_slot: Int32 = PJSUA_INVALID_ID.rawValue
        var ring_cnt: Int32 = 0
        var ring_port = UnsafeMutablePointer<pjmedia_port>(mutating: nil)
        
        var vid = app_vid()
        var aud_cnt: UInt32 = 1
    }
    
    private init() {}
    
    /*****************************************************************************
     * A simple module to handle otherwise unhandled request. We will register
     * this with the lowest priority.
     */
    
    /* Notification on incoming request */
    let default_mod_on_rx_request: @convention(c) (UnsafeMutablePointer<pjsip_rx_data>?) -> pj_bool_t = { rdata in
        var tdata: UnsafeMutablePointer<pjsip_tx_data>?
        var status_code: pjsip_status_code
        var status: pj_status_t
        
        var ack_method = pjsip_ack_method
        var notify_method = pjsip_notify_method
        
        /* Don't respond to ACK! */
        if (pjsip_method_cmp(&rdata!.pointee.msg_info.msg.pointee.line.req.method, &ack_method) == 0) {
            return pj_bool_t(PJ_TRUE.rawValue)
        }
        
        //        /* Simple registrar */
        //        if (pjsip_method_cmp(&rdata.pointee.msg_info.msg.pointee.line.req.method, &register_method) == 0) {
        //            simple_registrar(rdata)
        //            return pj_bool_t(PJ_TRUE.rawValue)
        //        }
        
        /* Create basic response. */
        if (pjsip_method_cmp(&rdata!.pointee.msg_info.msg.pointee.line.req.method, &notify_method) == 0)
        {
            /* Unsolicited NOTIFY's, send with Bad Request */
            status_code = PJSIP_SC_BAD_REQUEST
        } else {
            /* Probably unknown method */
            status_code = PJSIP_SC_METHOD_NOT_ALLOWED
        }
        
        status = pjsip_endpt_create_response(pjsua_get_pjsip_endpt(), rdata, Int32(status_code.rawValue), nil, &tdata)
        if (status != PJ_SUCCESS.rawValue) {
            print("Unable to create response, status: \(status)")
            return pj_bool_t(PJ_TRUE.rawValue)
        }
        
        /* Add Allow if we're responding with 405 */
        if (status_code == PJSIP_SC_METHOD_NOT_ALLOWED) {
            var cap_hdr: UnsafePointer<pjsip_hdr>?
            cap_hdr = pjsip_endpt_get_capability(pjsua_get_pjsip_endpt(), Int32(PJSIP_H_ALLOW.rawValue), nil)
            
            if (cap_hdr != nil) {
                let clone = pjsip_hdr_clone(tdata!.pointee.pool, cap_hdr)
                let opaque = OpaquePointer(clone)
                let header = UnsafeMutablePointer<pjsip_hdr>(opaque)
                
                pjsip_msg_add_hdr(tdata!.pointee.msg, header)
            }
        }
        
        /* Add User-Agent header */
        do {
            var user_agent = pj_str_t()
            var USER_AGENT = pj_str(UnsafeMutablePointer<Int8>(mutating: ("User-Agent" as NSString).utf8String))
            var h: UnsafeMutablePointer<pjsip_hdr>
            
            
            let str = ("PJSUA v\(String(cString: pj_get_version()))/\(PJ_OS_NAME)" as NSString).utf8String
            pj_strdup2_with_null(tdata!.pointee.pool, &user_agent, UnsafeMutablePointer<Int8>(mutating: str))
            
            let generic = pjsip_generic_string_hdr_create(tdata!.pointee.pool, &USER_AGENT, &user_agent)!
            h = UnsafeMutableRawPointer(generic).bindMemory(to: pjsip_hdr.self, capacity: 1)
            pjsip_msg_add_hdr(tdata!.pointee.msg, h)
        }
        
        pjsip_endpt_send_response2(pjsua_get_pjsip_endpt(), rdata, tdata, nil, nil)
        
        return pj_bool_t(PJ_TRUE.rawValue)
    }
    
    /* Add account */
    func addAccount() -> pj_status_t {
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
        
        pjsua_acc_set_online_status(current_acc, pj_bool_t(PJ_TRUE.rawValue))
        
        return status
    }
    
    func pjsuaStart() {
        var status: pj_status_t
        
        status = app_init()
        if (status != PJ_SUCCESS.rawValue) {
            var errmsg = Array(repeating: Int8(), count: Int(PJ_ERR_MSG_SIZE))
            pj_strerror(status, &errmsg, Int(PJ_ERR_MSG_SIZE))
            let data = Data(bytes: errmsg, count: errmsg.count)
            print("Pjsua Init Error: \(String(data: data, encoding: .utf8) ?? "")")
            
            // TODO: Add pjsua_app_destroy()
            //pjsua_app_destroy();
            fatalError()
        }
        
        status = app_run()
        if (status != PJ_SUCCESS.rawValue) {
            var errmsg = Array(repeating: Int8(), count: Int(PJ_ERR_MSG_SIZE))
            pj_strerror(status, &errmsg, Int(PJ_ERR_MSG_SIZE))
            let data = Data(bytes: errmsg, count: errmsg.count)
            print("Pjsua run Error: \(String(data: data, encoding: .utf8) ?? "")")
            
            // TODO: Add pjsua_app_destroy()
            //pjsua_app_destroy();
            fatalError()
        }
        
        status = addAccount()
        if (status != PJ_SUCCESS.rawValue) {
            var errmsg = Array(repeating: Int8(), count: Int(PJ_ERR_MSG_SIZE))
            pj_strerror(status, &errmsg, Int(PJ_ERR_MSG_SIZE))
            let data = Data(bytes: errmsg, count: errmsg.count)
            print("Pjsua add account Error: \(String(data: data, encoding: .utf8) ?? "")")
            
            // TODO: Add pjsua_app_destroy()
            //pjsua_app_destroy();
            fatalError()
        }
    }
    
    /* Set default config. */
    func default_config() -> pjsua_app_config {
        var cfg = app_config
        
        pjsua_config_default(&cfg.cfg)

        let str = ("PJSUA v\(String(cString: pj_get_version())) \(String(cString: pj_get_sys_info().pointee.info.ptr))" as NSString).utf8String
        cfg.cfg.user_agent = pj_str(UnsafeMutablePointer<Int8>(mutating: str))
        
        pjsua_logging_config_default(&cfg.log_cfg)
        
        pjsua_media_config_default(&cfg.media_cfg)
        
        pjsua_transport_config_default(&cfg.udp_cfg)
        cfg.udp_cfg.port = 5060
        
        pjsua_transport_config_default(&cfg.rtp_cfg)
        cfg.rtp_cfg.port = 4000
        
        // Pete, added for test
        cfg.cfg.outbound_proxy_cnt = 1
        cfg.cfg.outbound_proxy.0 = pj_str(UnsafeMutablePointer<Int8>(mutating: ("sips:siptest.butterflymx.com" as NSString).utf8String))
        
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
    
    func app_run() -> pj_status_t {
        var status: pj_status_t
        
        status = pjsua_start()
        if (status != PJ_SUCCESS.rawValue) {
            return status
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
        }
        
        // Set video codec priority
        print("Reset video codec priorities.")
        
        var videoCodec: pj_str_t = pj_str_t()
        
        pjsua_vid_codec_set_priority(pj_cstr(&videoCodec, "H264/97"), pj_uint8_t(PJMEDIA_CODEC_PRIO_HIGHEST.rawValue))
        
        if (pjsua_vid_enum_codecs(UnsafeMutablePointer(mutating: videoCodecs), &videoCodecsCount) == Int32(PJ_SUCCESS.rawValue)) {
            print("List of video codecs after reset priorities:")
            
            for i in 0..<videoCodecsCount {
                print("ID: \(String(cString: videoCodecs[Int(i)].codec_id.ptr)), priority: \(Int(videoCodecs[Int(i)].priority))")
            }
        }
        
        return status
    }
    
    func app_init() -> pj_status_t {
        /* The module instance. */
        var mod_default_handler = pjsip_module(
            prev: nil,
            next: nil,
            name: pj_str(UnsafeMutablePointer<Int8>(mutating: ("mod-default-handler" as NSString).utf8String)),
            id: -1,
            priority: Int32(PJSIP_MOD_PRIORITY_APPLICATION.rawValue + 99),
            load: nil,
            start: nil,
            stop: nil,
            unload: nil,
            on_rx_request: default_mod_on_rx_request,
            on_rx_response: nil,
            on_tx_request: nil,
            on_tx_response: nil,
            on_tsx_state: nil
        )
        
        var transport_id: pjsua_transport_id = -1
        var tcp_cfg = pjsua_transport_config()
        var status: pj_status_t
        
        /** Create pjsua **/
        status = pjsua_create()
        if status != PJ_SUCCESS.rawValue {
            return status
        }
        
        app_config = default_config()
        
        /* Initialize application callbacks */
        app_config.cfg.cb.on_call_state = on_call_state
        app_config.cfg.cb.on_call_media_state = on_call_media_state
        app_config.cfg.cb.on_incoming_call = on_incoming_call
        app_config.cfg.cb.on_call_tsx_state = on_call_tsx_state
        app_config.cfg.cb.on_reg_state = on_reg_state
        app_config.cfg.cb.on_transport_state = on_transport_state
        app_config.cfg.cb.on_snd_dev_operation = on_snd_dev_operation
        app_config.cfg.cb.on_call_media_event = on_call_media_event
        
        /* Set sound device latency */
        if (app_config.capture_lat > 0) {
            app_config.media_cfg.snd_rec_latency = app_config.capture_lat
        }
        
        if (app_config.playback_lat != 0) {
            app_config.media_cfg.snd_play_latency = app_config.playback_lat
        }
        
        /* Initialize pjsua */
        status = pjsua_init(&(app_config.cfg), &(app_config.log_cfg), &(app_config.media_cfg))
        if (status != PJ_SUCCESS.rawValue) {
            return status
        }
        
        // TODO: Enable module handler will cause pjsua_acc_add() error. Why?
//        /* Initialize our module to handle otherwise unhandled request */
//        status = pjsip_endpt_register_module(pjsua_get_pjsip_endpt(), &mod_default_handler)
//        if (status != PJ_SUCCESS.rawValue) {
//            return status
//        }
        
//        /* Initialize calls data */
//        for i in 0..<app_config.call_data.count {
//            app_config.call_data[i].timer.id = PJSUA_INVALID_ID.rawValue
//            app_config.call_data[i].timer.cb = &call_timeout_callback
//        }
        
        /* Add UDP transport unless it's disabled. */
        if (app_config.no_udp == PJ_FALSE.rawValue) {
            let type: pjsip_transport_type_e = PJSIP_TRANSPORT_UDP
            
            status = pjsua_transport_create(type, &app_config.udp_cfg, &transport_id)
            if (status != PJ_SUCCESS.rawValue) { return status }
        }

        
        //#if defined(PJSIP_HAS_TLS_TRANSPORT) && PJSIP_HAS_TLS_TRANSPORT!=0
        /* Add TLS transport when application wants one */
        if (app_config.use_tls != 0) {
            
            //var acc_id = pjsua_acc_id()
            
            /* Copy the QoS settings */
            tcp_cfg.tls_setting.qos_type = tcp_cfg.qos_type
            tcp_cfg.tls_setting.qos_params = tcp_cfg.qos_params
            
            /* Set TLS port as TCP port+1 */
            tcp_cfg.port += 1
            status = pjsua_transport_create(PJSIP_TRANSPORT_TLS, &tcp_cfg, &transport_id)
            tcp_cfg.port -= 1
            if (status != PJ_SUCCESS.rawValue) {
                return status
            }
        }
        
        if (transport_id == -1) {
            print("Error: no transport is configured")
            status = -1
            return status
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
        
        /* Use null sound device? */
        if (app_config.null_audio != 0) {
            print("Set null sound device")
            status = pjsua_set_null_snd_dev()
            if (status != PJ_SUCCESS.rawValue) {
                return status
            }
        }
        
        if (app_config.capture_dev != PJSUA_INVALID_ID.rawValue ||
            app_config.playback_dev != PJSUA_INVALID_ID.rawValue)
        {
            status = pjsua_set_snd_dev(app_config.capture_dev,
                                       app_config.playback_dev)
            if (status != PJ_SUCCESS.rawValue) {
                return status
            }
        }
        
        /* Init call setting */
        pjsua_call_setting_default(&call_opt)
        call_opt.aud_cnt = app_config.aud_cnt
        call_opt.vid_cnt = app_config.vid.vid_cnt
        
        return pj_status_t(PJ_SUCCESS.rawValue)
    }
    
    /*
     * Notification on sound device operation.
     */
    let on_snd_dev_operation: @convention(c) (Int32) -> pj_status_t = { operation in
        var play_dev: Int32 = 0
        var cap_dev: Int32 = 0
    
        pjsua_get_snd_dev(&cap_dev, &play_dev)
        print("Turning sound device \(cap_dev) \(play_dev) \((operation == 1 ? "ON" : "OFF"))")
    
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

//        DispatchQueue.main.async {
//            NotificationCenter.default.post(name: SIPNotification.registrationState.notification, object: nil, userInfo: ["accountID" : accountID, "statusText" : String(cString: info.status_text.ptr), "status" : info.status])
//        }
    }
    
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
    
    /*
     * Handler when invite state has changed.
     */
    let on_call_state: @convention(c) (pjsua_call_id, UnsafeMutablePointer<pjsip_event>?) -> Void = { call_id, event in
        
        var call_info = pjsua_call_info()
        
        pjsua_call_get_info(call_id, &call_info)
        
        if (call_info.state == PJSIP_INV_STATE_DISCONNECTED) {
            
            /* Stop all ringback for this call */
            PjsuaApp.shared.ring_stop(call_id)
            
            /* Cancel duration timer, if any */
            if (PjsuaApp.shared.app_config.call_data[Int(call_id)].timer.id != PJSUA_INVALID_ID.rawValue) {
                var cd: app_call_data = PjsuaApp.shared.app_config.call_data[Int(call_id)]
                let endpt = pjsua_get_pjsip_endpt()
                
                cd.timer.id = PJSUA_INVALID_ID.rawValue
                pjsip_endpt_cancel_timer(endpt, &cd.timer)
            }
            
            print("Call \(call_id) is DISCONNECTED [reason=\(call_info.last_status.rawValue) \(String(cString: call_info.last_status_text.ptr))]")
            
            if (call_id == PjsuaApp.shared.current_call) {
                _ = PjsuaApp.shared.find_next_call()
            }
            
            /* Dump media state upon disconnected */
            print("Call \(call_id) disconnected")
            
        } else {
            if (call_info.state == PJSIP_INV_STATE_EARLY) {
                var code: Int
                var reason: pj_str_t
                var msg: pjsip_msg
                let e = event!.pointee
                
                /* This can only occur because of TX or RX message */
                assert(e.type == PJSIP_EVENT_TSX_STATE)
                
                if (e.body.tsx_state.type == PJSIP_EVENT_RX_MSG) {
                    msg = e.body.tsx_state.src.rdata.pointee.msg_info.msg.pointee
                } else {
                    msg = e.body.tsx_state.src.tdata.pointee.msg.pointee
                }
                
                code = Int(msg.line.status.code)
                reason = msg.line.status.reason
                
                /* Start ringback for 180 for UAC unless there's SDP in 180 */
                if (call_info.role == PJSIP_ROLE_UAC && code == 180 && msg.body == nil && call_info.media_status == PJSUA_CALL_MEDIA_NONE)
                {
                    PjsuaApp.shared.ringback_start(call_id)
                }
                
                print("Call \(call_id) state changed to \(call_info.state_text.ptr.pointee) (\(code) \(reason))")
            } else {
                print("Call \(call_id) state changed to \(call_info.state_text.ptr.pointee)")
            }
            
            if PjsuaApp.shared.current_call == PJSUA_INVALID_ID.rawValue {
                PjsuaApp.shared.current_call = call_id
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
        //ring_stop(ci.id) // TODO: Add ring_stop
        
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
        
        media_index = media[mi].index
        
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
//                        videoView.bounds = CGRect(x: 0, y: 0, width: topVC.view.bounds.size.width, height: topVC.view.bounds.size.height * 1.0 * topVC.view.bounds.size.width / videoView.bounds.size.width)
                        videoView.bounds = CGRect(x: 0, y: 0, width: topVC.view.bounds.size.width, height: topVC.view.bounds.size.height / 2.0)
                        /* Center it horizontally */
                        videoView.center = CGPoint(x: topVC.view.bounds.size.width / 2.0, y: videoView.bounds.size.height / 2.0)
                        //                    // Show window
                        //                    print("i: \(i)")
                        //                    pjsua_vid_win_set_show(i, pj_bool_t(PJ_TRUE.rawValue))
                    } else {
                        videoView.bounds.size.width = topVC.view.bounds.size.width / 4.0
                        videoView.bounds.size.height = topVC.view.bounds.size.height / 4.0
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
        
        print("==Media count: \(call_info.media_cnt)")
        for mi in 0..<Int(call_info.media_cnt) {
            var mediaTuple = call_info.media
            let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
                let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
                let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
                
                return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
            }
            
            switch media[Int(mi)].type {
            case PJMEDIA_TYPE_AUDIO:
                print("==Audio media")
                PjsuaApp.shared.on_call_audio_state(call_info, mi, has_error)
            case PJMEDIA_TYPE_VIDEO:
                print("==Video media")
                PjsuaApp.shared.on_call_video_state(call_info, mi, has_error)
            default:
                break
            }
        }
        
        if has_error == pj_bool_t(PJ_TRUE.rawValue) {
            var reason = pj_str(UnsafeMutablePointer<Int8>(mutating: ("Media failed" as NSString).utf8String))
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
    
    func ringback_start(_ call_id: pjsua_call_id ) {
        if (app_config.no_tones == PJ_TRUE.rawValue) { return }
        
        if (app_config.call_data[Int(call_id)].ringback_on == PJ_TRUE.rawValue) { return }
        
        app_config.call_data[Int(call_id)].ringback_on = pj_bool_t(PJ_TRUE.rawValue)
        
        app_config.ringback_cnt += 1
        
        if (app_config.ringback_cnt == 1 && app_config.ringback_slot != PJSUA_INVALID_ID.rawValue) {
            pjsua_conf_connect(app_config.ringback_slot, 0)
        }
    }

    func ring_start(_ call_id: pjsua_call_id) {
        if (app_config.no_tones) == pj_bool_t(PJ_TRUE.rawValue) { return }
        
        if (app_config.call_data[Int(call_id)].ring_on == pj_bool_t(PJ_TRUE.rawValue)) { return }
        
        app_config.call_data[Int(call_id)].ring_on = pj_bool_t(PJ_TRUE.rawValue)
        
        app_config.ring_cnt += 1
        
        if (app_config.ring_cnt == 1), app_config.ring_slot != PJSUA_INVALID_ID.rawValue {
            pjsua_conf_connect(app_config.ring_slot, 0)
        }
    }
    
    func ring_stop(_ call_id: pjsua_call_id) {
        if app_config.no_tones == pj_bool_t(PJ_TRUE.rawValue) { return }
        
        if app_config.call_data[Int(call_id)].ringback_on == pj_bool_t(PJ_TRUE.rawValue) {
            app_config.call_data[Int(call_id)].ringback_on = pj_bool_t(PJ_FALSE.rawValue)
            
            assert(app_config.ringback_cnt > 0)
            
            app_config.ringback_cnt -= 1
            
            if app_config.ringback_cnt == 0, app_config.ringback_slot != PJSUA_INVALID_ID.rawValue {
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
  
    /*
     * Handler when a transaction within a call has changed state.
     */
    let on_call_tsx_state: @convention(c) (pjsua_call_id, UnsafeMutablePointer<pjsip_transaction>?, UnsafeMutablePointer<pjsip_event>?) -> Void = { call_id, tsx, e in
        let name = pj_str(UnsafeMutablePointer<Int8>(mutating: ("INFO" as NSString).utf8String))
        var info_method = pjsip_method(id: PJSIP_OTHER_METHOD, name: name)
        
        if (pjsip_method_cmp(&(tsx!.pointee.method), &info_method) == 0) {
            /*
             * Handle INFO method.
             */
            var STR_APPLICATION = pj_str(UnsafeMutablePointer<Int8>(mutating: ("application" as NSString).utf8String))
            var STR_DTMF_RELAY = pj_str(UnsafeMutablePointer<Int8>(mutating: ("dtmf-relay" as NSString).utf8String))
            var body: pjsip_msg_body? = nil
            var dtmf_info: pj_bool_t = pj_bool_t(PJ_FALSE.rawValue)
            
            if (tsx!.pointee.role == PJSIP_ROLE_UAC) {
                if (e!.pointee.body.tsx_state.type == PJSIP_EVENT_TX_MSG) {
                    body = e!.pointee.body.tsx_state.src.tdata.pointee.msg.pointee.body.pointee
                } else {
                    body = e!.pointee.body.tsx_state.tsx!.pointee.last_tx.pointee.msg.pointee.body.pointee
                }
            } else {
                if (e!.pointee.body.tsx_state.type == PJSIP_EVENT_RX_MSG) {
                    body = e!.pointee.body.tsx_state.src.rdata.pointee.msg_info.msg.pointee.body.pointee
                }
            }
            
            /* Check DTMF content in the INFO message */
            if (body != nil && body!.len != 0 &&
                pj_stricmp(&body!.content_type.type, &STR_APPLICATION)==0 &&
                pj_stricmp(&body!.content_type.subtype, &STR_DTMF_RELAY)==0) {
                dtmf_info = pj_bool_t(PJ_TRUE.rawValue)
            }
            
            let prev_state = e!.pointee.body.tsx_state.prev_state
            if (dtmf_info == pj_bool_t(PJ_TRUE.rawValue) && tsx!.pointee.role == PJSIP_ROLE_UAC &&
                (tsx!.pointee.state == PJSIP_TSX_STATE_COMPLETED ||
                    (tsx!.pointee.state == PJSIP_TSX_STATE_TERMINATED && prev_state != PJSIP_TSX_STATE_COMPLETED.rawValue))) {
                /* Status of outgoing INFO request */
                if (tsx!.pointee.status_code >= 200 && tsx!.pointee.status_code < 300) {
                    print("Call \(call_id): DTMF sent successfully with INFO")
                } else if (tsx!.pointee.status_code >= 300) {
                    print("Call \(call_id): Failed to send DTMF with INFO: \(tsx!.pointee.status_code)/\(tsx!.pointee.status_text.ptr)")
                }
            } else if (dtmf_info == pj_bool_t(PJ_TRUE.rawValue) && tsx!.pointee.role == PJSIP_ROLE_UAS &&
                tsx!.pointee.state == PJSIP_TSX_STATE_TRYING) {
                /* Answer incoming INFO with 200/OK */
                var rdata: UnsafeMutablePointer<pjsip_rx_data>
                var tdata: UnsafeMutablePointer<pjsip_tx_data>?
                var status: pj_status_t
                
                rdata = e!.pointee.body.tsx_state.src.rdata
                
                if ((rdata.pointee.msg_info.msg.pointee.body) != nil) {
                    status = pjsip_endpt_create_response(tsx!.pointee.endpt, rdata, 200, nil, &tdata)
                    if (status == PJ_SUCCESS.rawValue) {
                        status = pjsip_tsx_send_msg(tsx, tdata)
                    }
                    
                    print("Call \(call_id): incoming INFO: \(rdata.pointee.msg_info.msg.pointee.body.pointee.data)")
                } else {
                    status = pjsip_endpt_create_response(tsx!.pointee.endpt, rdata, 400, nil, &tdata)
                    if (status == PJ_SUCCESS.rawValue) {
                        status = pjsip_tsx_send_msg(tsx, tdata)
                    }
                }
            }
        }
    }
    
    let on_incoming_call: @convention(c) (pjsua_acc_id, pjsua_call_id, UnsafeMutablePointer<pjsip_rx_data>?) -> Void = { acc_id, call_id, rdata in
        var call_info = pjsua_call_info()
        
        pjsua_call_get_info(call_id, &call_info)
        
        if PjsuaApp.shared.current_call == PJSUA_INVALID_ID.rawValue {
            PjsuaApp.shared.current_call = call_id
        }
        
        /* Start ringback */
        PjsuaApp.shared.ring_start(call_id)
        
        if (PjsuaApp.shared.app_config.auto_answer > 0) {
            var opt = pjsua_call_setting()
            
            pjsua_call_setting_default(&opt)
            opt.aud_cnt = PjsuaApp.shared.app_config.aud_cnt
            opt.vid_cnt = PjsuaApp.shared.app_config.vid.vid_cnt
            
            pjsua_call_answer2(call_id, &opt, PjsuaApp.shared.app_config.auto_answer, nil, nil)
        }
        
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
        
        print("Event \(String(cString: pjmedia_fourcc_name(event!.pointee.type.rawValue, &event_name)))")
        
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
            print("SIP \(String(cString: tp.type_name)) transport is connected to \(host_port)")
        case PJSIP_TP_STATE_DISCONNECTED:
            print("SIP \(String(cString: tp.type_name)) transport is disconnected from \(host_port)")
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
            var verif_msgs = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 32)
            var verif_msg_cnt: UInt32 = 32
            
            /* Dump server TLS cipher */
            let cipher = ssl_sock_info.cipher.rawValue
            print("TLS cipher used: 0x\(String(format: "%x", cipher))/\(String(cString: pj_ssl_cipher_name(ssl_sock_info.cipher)))")
            
            /* Dump server TLS certificate */
            pj_ssl_cert_info_dump(ssl_sock_info.remote_cert_info, "  ", &buf, 2048)
            print("TLS cert info of \(host_port):")
            print(String(cString: buf))
            
            /* Dump server TLS certificate verification result */
            //verif_msg_cnt = UInt32(verif_msgs.count)
            pj_ssl_cert_get_verify_status_strings(ssl_sock_info.verify_status, verif_msgs, &verif_msg_cnt)
            
            print("TLS cert verification result of \(host_port): \(verif_msg_cnt == 1 ? String(cString: verif_msgs[0]!) : "")")
            
            if (verif_msg_cnt > 1) {
                for i in 0..<Int(verif_msg_cnt) {
                    print("- \(verif_msgs[i]!)")
                }
            }

            if (ssl_sock_info.verify_status != 0 && PjsuaApp.shared.app_config.udp_cfg.tls_setting.verify_server == 0) {
                print("PJSUA is configured to ignore TLS cert verification errors")
            }
            
            verif_msgs.deallocate(capacity: 32)
        }
        //    #endif
    }
    
}
