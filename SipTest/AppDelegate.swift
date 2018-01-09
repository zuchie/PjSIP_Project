//
//  AppDelegate.swift
//  SipTest
//
//  Created by Zhe Cui on 12/17/17.
//  Copyright © 2017 Zhe Cui. All rights reserved.
//

import UIKit
import PushKit

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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate {

    var window: UIWindow?
    var captureDeviceID: Int32 = -1000
    var playbackDeviceID: Int32 = -1000
    var voipRegistry: PKPushRegistry!
    
    let PJSUA_APP_NO_LIMIT_DURATION: CUnsignedInt = 0x7FFFFFFF
    let PJSUA_APP_NO_NB = -2

    var current_acc = pjsua_acc_get_default()
    var call_opt = pjsua_call_setting()
    
    //var app = PjsuaApp()
    
    class var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    var providerDelegate: ProviderDelegate!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Register VoIP
        self.voipRegistration()
        
        // CallKit and PJSUA configure
        providerDelegate = ProviderDelegate()
        
        pjsuaStart()
        
        
//        var status: pj_status_t
//
//        status = pjsua_create()
//
//        if status != PJ_SUCCESS.rawValue {
//            print("Error creating pjsua, status: \(status)")
//            return false
//        }
//
//        var pjsuaConfig = pjsua_config()
//        var pjsuaMediaConfig = pjsua_media_config()
//        var pjsuaLoggingConfig = pjsua_logging_config()
//
//        pjsua_config_default(&pjsuaConfig)
//
//        pjsuaConfig.cb.on_incoming_call = onIncomingCall
//        pjsuaConfig.cb.on_call_media_state = onCallMediaState
//        pjsuaConfig.cb.on_call_state = onCallState
//        pjsuaConfig.cb.on_reg_state = onRegState
//
//        // Have to add proxy in order to use "sip" instead of "sips" for full URI
//        pjsuaConfig.outbound_proxy_cnt = 1;
//        pjsuaConfig.outbound_proxy.0 = pj_str(UnsafeMutablePointer<Int8>(mutating: ("sips:siptest.butterflymx.com:5061" as NSString).utf8String))
//
//
//        // Media config
//        pjsua_media_config_default(&pjsuaMediaConfig)
//        pjsuaMediaConfig.clock_rate = 16000
//        pjsuaMediaConfig.snd_clock_rate = 16000
//        pjsuaMediaConfig.ec_tail_len = 0
//
//        // Logging config
//        pjsua_logging_config_default(&pjsuaLoggingConfig)
//#if DEBUG
//        pjsuaLoggingConfig.msg_logging = pj_bool_t(PJ_TRUE.rawValue)
//        pjsuaLoggingConfig.console_level = 5
//        pjsuaLoggingConfig.level = 5
//#else
//        pjsuaLoggingConfig.msg_logging = pj_bool_t(PJ_FALSE.rawValue)
//        pjsuaLoggingConfig.console_level = 0
//        pjsuaLoggingConfig.level = 0
//#endif
//
//        // Init
//        status = pjsua_init(&pjsuaConfig, &pjsuaLoggingConfig, &pjsuaMediaConfig)
//
//        if status != PJ_SUCCESS.rawValue {
//            print("Error initializing pjsua, status: \(status)")
//
//            return false
//        }
//
//        // Transport config
//        var pjsuaTransportConfig = pjsua_transport_config()
//
//        pjsua_transport_config_default(&pjsuaTransportConfig)
//
//        /*
//        status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &pjsuaTransportConfig, nil)
//        if status != PJ_SUCCESS.rawValue {
//            print("Error creating UDP transport, status: \(status)")
//            return false
//        }
//        */
//        //let transportID: pjsua_transport_id = -1
//
//        pjsuaTransportConfig.port = 5061
//        status = pjsua_transport_create(PJSIP_TRANSPORT_TLS, &pjsuaTransportConfig, nil)
//
//        if status != PJ_SUCCESS.rawValue {
//            print("Error creating TLS transport, status: \(status)")
//            return false
//        }
//
//        status = pjsua_start()
//        if status != PJ_SUCCESS.rawValue {
//            print("Error starting pjsua, status: \(status)")
//            return false
//        }
        
        
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
        
//        // Get sound devices
//        status = pjsua_get_snd_dev(&captureDeviceID, &playbackDeviceID)
//        if status != PJ_SUCCESS.rawValue {
//            print("Error get sound dev IDs, status: \(status)")
//            fatalError()
//        }
//
//        // Disconnect sound devices
//        pjsua_set_no_snd_dev()
        
        return true
    }
    
    /* Add account */
    func cmd_add_account() -> pj_status_t {
        var acc_cfg = pjsua_acc_config()
        var status: pj_status_t
        
        let fullURL = ("sip:6728@siptest.butterflymx.com" as NSString).utf8String
        // Always use "sips" for server
        let uri = ("sips:siptest.butterflymx.com" as NSString).utf8String
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
        acc_cfg.cred_info.0.scheme = pj_str(UnsafeMutablePointer<Int8>(mutating: "Digest"))
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
        
        //    if (app_config.use_cli && (app_config.cli_cfg.cli_fe & CLI_FE_TELNET)) {
        //        char info[128];
        //        cli_get_info(info, sizeof(info));
        //        if (app_cfg.on_started) {
        //            (*app_cfg.on_started)(status, info);
        //        }
        //    } else {
        //    if (app_cfg.on_started) {
        //    (*app_cfg.on_started)(status, "Ready");
        //    }
        //    }
        
        //    /* If user specifies URI to call, then call the URI */
        //    if (uri_arg.slen) {
        //        pjsua_call_setting_default(&call_opt);
        //        call_opt.aud_cnt = app_config.aud_cnt;
        //        call_opt.vid_cnt = app_config.vid.vid_cnt;
        //
        //        pjsua_call_make_call(current_acc, &uri_arg, &call_opt, NULL,
        //                             NULL, NULL);
        //    }
        
        //    app_running = PJ_TRUE;
        
        //    if (app_config.use_cli)
        //        cli_main(wait_telnet_cli);
        //    else
        //        legacy_main();
        
        //status = pj_status_t(PJ_SUCCESS.rawValue)
        
        //    on_return:
        //    if (stdout_refresh_thread) {
        //        stdout_refresh_quit = PJ_TRUE;
        //        pj_thread_join(stdout_refresh_thread);
        //        pj_thread_destroy(stdout_refresh_thread);
        //        stdout_refresh_quit = PJ_FALSE;
        //    }
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
        
        //    /* Initialize our module to handle otherwise unhandled request */
        //    status = pjsip_endpt_register_module(pjsua_get_pjsip_endpt(),
        //                                         &mod_default_handler);
        //    if (status != PJ_SUCCESS)
        //        return status;
        
        //#ifdef STEREO_DEMO
        //    stereo_demo();
        //#endif
        
        //    /* Initialize calls data */
        //    for (i=0; i<PJ_ARRAY_SIZE(app_config.call_data); ++i) {
        //    app_config.call_data[i].timer.id = PJSUA_INVALID_ID;
        //    app_config.call_data[i].timer.cb = &call_timeout_callback;
        //    }
        
        //    /* Optionally registers WAV file */
        //    for (i=0; i<app_config.wav_count; ++i) {
        //        pjsua_player_id wav_id;
        //        unsigned play_options = 0;
        //
        //        if (app_config.auto_play_hangup)
        //            play_options |= PJMEDIA_FILE_NO_LOOP;
        //
        //        status = pjsua_player_create(&app_config.wav_files[i], play_options,
        //                                     &wav_id);
        //        if (status != PJ_SUCCESS)
        //            goto on_error;
        //
        //        if (app_config.wav_id == PJSUA_INVALID_ID) {
        //            app_config.wav_id = wav_id;
        //            app_config.wav_port = pjsua_player_get_conf_port(app_config.wav_id);
        //            if (app_config.auto_play_hangup) {
        //                pjmedia_port *port;
        //
        //                pjsua_player_get_port(app_config.wav_id, &port);
        //                status = pjmedia_wav_player_set_eof_cb(port, NULL,
        //                                                       &on_playfile_done);
        //                if (status != PJ_SUCCESS)
        //                    goto on_error;
        //
        //                pj_timer_entry_init(&app_config.auto_hangup_timer, 0, NULL,
        //                                    &hangup_timeout_callback);
        //            }
        //        }
        //    }
        
        //    /* Optionally registers tone players */
        //    for (i=0; i<app_config.tone_count; ++i) {
        //    pjmedia_port *tport;
        //    char name[80];
        //    pj_str_t label;
        //    pj_status_t status2;
        //
        //    pj_ansi_snprintf(name, sizeof(name), "tone-%d,%d",
        //    app_config.tones[i].freq1,
        //    app_config.tones[i].freq2);
        //    label = pj_str(name);
        //    status2 = pjmedia_tonegen_create2(app_config.pool, &label,
        //    8000, 1, 160, 16,
        //    PJMEDIA_TONEGEN_LOOP,  &tport);
        //    if (status2 != PJ_SUCCESS) {
        //    pjsua_perror(THIS_FILE, "Unable to create tone generator", status);
        //    goto on_error;
        //    }
        //
        //    status2 = pjsua_conf_add_port(app_config.pool, tport,
        //    &app_config.tone_slots[i]);
        //    pj_assert(status2 == PJ_SUCCESS);
        //
        //    status2 = pjmedia_tonegen_play(tport, 1, &app_config.tones[i], 0);
        //    pj_assert(status2 == PJ_SUCCESS);
        //    }
        
        //    /* Optionally create recorder file, if any. */
        //    if (app_config.rec_file.slen) {
        //        status = pjsua_recorder_create(&app_config.rec_file, 0, NULL, 0, 0,
        //                                       &app_config.rec_id);
        //        if (status != PJ_SUCCESS)
        //            goto on_error;
        //
        //        app_config.rec_port = pjsua_recorder_get_conf_port(app_config.rec_id);
        //    }
        
        //    pj_memcpy(&tcp_cfg, &app_config.udp_cfg, sizeof(tcp_cfg));
        
        //    /* Create ringback tones */
        //    if (app_config.no_tones == PJ_FALSE) {
        //    unsigned samples_per_frame;
        //    pjmedia_tone_desc tone[RING_CNT+RINGBACK_CNT];
        //    pj_str_t name;
        //
        //    samples_per_frame = app_config.media_cfg.audio_frame_ptime *
        //    app_config.media_cfg.clock_rate *
        //    app_config.media_cfg.channel_count / 1000;
        //
        //    /* Ringback tone (call is ringing) */
        //    name = pj_str("ringback");
        //    status = pjmedia_tonegen_create2(app_config.pool, &name,
        //    app_config.media_cfg.clock_rate,
        //    app_config.media_cfg.channel_count,
        //    samples_per_frame,
        //    16, PJMEDIA_TONEGEN_LOOP,
        //    &app_config.ringback_port);
        //    if (status != PJ_SUCCESS)
        //    goto on_error;
        //
        //    pj_bzero(&tone, sizeof(tone));
        //    for (i=0; i<RINGBACK_CNT; ++i) {
        //    tone[i].freq1 = RINGBACK_FREQ1;
        //    tone[i].freq2 = RINGBACK_FREQ2;
        //    tone[i].on_msec = RINGBACK_ON;
        //    tone[i].off_msec = RINGBACK_OFF;
        //    }
        //    tone[RINGBACK_CNT-1].off_msec = RINGBACK_INTERVAL;
        //
        //    pjmedia_tonegen_play(app_config.ringback_port, RINGBACK_CNT, tone,
        //    PJMEDIA_TONEGEN_LOOP);
        //
        //
        //    status = pjsua_conf_add_port(app_config.pool, app_config.ringback_port,
        //    &app_config.ringback_slot);
        //    if (status != PJ_SUCCESS)
        //    goto on_error;
        //
        //    /* Ring (to alert incoming call) */
        //    name = pj_str("ring");
        //    status = pjmedia_tonegen_create2(app_config.pool, &name,
        //    app_config.media_cfg.clock_rate,
        //    app_config.media_cfg.channel_count,
        //    samples_per_frame,
        //    16, PJMEDIA_TONEGEN_LOOP,
        //    &app_config.ring_port);
        //    if (status != PJ_SUCCESS)
        //    goto on_error;
        //
        //    for (i=0; i<RING_CNT; ++i) {
        //    tone[i].freq1 = RING_FREQ1;
        //    tone[i].freq2 = RING_FREQ2;
        //    tone[i].on_msec = RING_ON;
        //    tone[i].off_msec = RING_OFF;
        //    }
        //    tone[RING_CNT-1].off_msec = RING_INTERVAL;
        //
        //    pjmedia_tonegen_play(app_config.ring_port, RING_CNT,
        //    tone, PJMEDIA_TONEGEN_LOOP);
        //
        //    status = pjsua_conf_add_port(app_config.pool, app_config.ring_port,
        //    &app_config.ring_slot);
        //    if (status != PJ_SUCCESS)
        //    goto on_error;
        //
        //    }
        
        //    for (i=0; i<app_config.avi_cnt; ++i) {
        //    pjmedia_avi_dev_param avdp;
        //    pjmedia_vid_dev_index avid;
        //    unsigned strm_idx, strm_cnt;
        //
        //    app_config.avi[i].dev_id = PJMEDIA_VID_INVALID_DEV;
        //    app_config.avi[i].slot = PJSUA_INVALID_ID;
        //
        //    pjmedia_avi_dev_param_default(&avdp);
        //    avdp.path = app_config.avi[i].path;
        //
        //    status =  pjmedia_avi_dev_alloc(avi_factory, &avdp, &avid);
        //    if (status != PJ_SUCCESS) {
        //    PJ_PERROR(1,(THIS_FILE, status,
        //    "Error creating AVI player for %.*s",
        //    (int)avdp.path.slen, avdp.path.ptr));
        //    goto on_error;
        //    }
        //
        //    PJ_LOG(4,(THIS_FILE, "AVI player %.*s created, dev_id=%d",
        //    (int)avdp.title.slen, avdp.title.ptr, avid));
        //
        //    app_config.avi[i].dev_id = avid;
        //    if (app_config.avi_def_idx == PJSUA_INVALID_ID)
        //    app_config.avi_def_idx = i;
        //
        //    strm_cnt = pjmedia_avi_streams_get_num_streams(avdp.avi_streams);
        //    for (strm_idx=0; strm_idx<strm_cnt; ++strm_idx) {
        //    pjmedia_port *aud;
        //    pjmedia_format *fmt;
        //    pjsua_conf_port_id slot;
        //    char fmt_name[5];
        //
        //    aud = pjmedia_avi_streams_get_stream(avdp.avi_streams,
        //    strm_idx);
        //    fmt = &aud->info.fmt;
        //
        //    pjmedia_fourcc_name(fmt->id, fmt_name);
        //
        //    if (fmt->id == PJMEDIA_FORMAT_PCM) {
        //    status = pjsua_conf_add_port(app_config.pool, aud,
        //    &slot);
        //    if (status == PJ_SUCCESS) {
        //    PJ_LOG(4,(THIS_FILE,
        //    "AVI %.*s: audio added to slot %d",
        //    (int)avdp.title.slen, avdp.title.ptr,
        //    slot));
        //    app_config.avi[i].slot = slot;
        //    }
        //    } else {
        //    PJ_LOG(4,(THIS_FILE,
        //    "AVI %.*s: audio ignored, format=%s",
        //    (int)avdp.title.slen, avdp.title.ptr,
        //    fmt_name));
        //    }
        //    }
        //    }
        //    #else
        //    PJ_LOG(2,(THIS_FILE,
        //    "Warning: --play-avi is ignored because AVI is disabled"));
        //    #endif    /* PJMEDIA_VIDEO_DEV_HAS_AVI */
        //    }
        
        //    /* Add UDP transport unless it's disabled. */
        //        if (app_config.no_udp == 0) {
        //            var aid: pjsua_acc_id
        //            var type: pjsip_transport_type_e = PJSIP_TRANSPORT_UDP
        //
        //            status = pjsua_transport_create(type, &app_config.udp_cfg, &transport_id)
        //            if (status != PJ_SUCCESS.rawValue) {
        //                pj_pool_release(tmp_pool)
        //                //app_destroy()
        //                return status
        //            }
        //
        //    /* Add local account */
        //    pjsua_acc_add_local(transport_id, PJ_TRUE, &aid)
        //
        //    /* Adjust local account config based on pjsua app config */
        //    {
        //        var acc_cfg: pjsua_acc_config
        //        pjsua_acc_get_config(aid, tmp_pool, &acc_cfg)
        //
        //    app_config_init_video(&acc_cfg);
        //    acc_cfg.rtp_cfg = app_config.rtp_cfg;
        //    pjsua_acc_modify(aid, &acc_cfg);
        //    }
        
        //pjsua_acc_set_transport(aid, transport_id);
        //    pjsua_acc_set_online_status(current_acc, pj_bool_t(PJ_TRUE.rawValue))
        //
        //            if (app_config.udp_cfg.port == 0) {
        //                var ti: pjsua_transport_info
        //                var a: UnsafeMutablePointer<pj_sockaddr_in>
        //
        //                pjsua_transport_get_info(transport_id, &ti)
        //                a = ti.local_addr
        //
        //                tcp_cfg.port = pj_ntohs(a.pointee.sin_port)
        //            }
        //        }
        
        //    /* Add UDP IPv6 transport unless it's disabled. */
        //    if (!app_config.no_udp && app_config.ipv6) {
        //    pjsua_acc_id aid;
        //    pjsip_transport_type_e type = PJSIP_TRANSPORT_UDP6;
        //    pjsua_transport_config udp_cfg;
        //
        //    udp_cfg = app_config.udp_cfg;
        //    if (udp_cfg.port == 0)
        //    udp_cfg.port = 5060;
        //    else
        //    udp_cfg.port += 10;
        //    status = pjsua_transport_create(type,
        //    &udp_cfg,
        //    &transport_id);
        //    if (status != PJ_SUCCESS)
        //    goto on_error;
        //
        //    /* Add local account */
        //    pjsua_acc_add_local(transport_id, PJ_TRUE, &aid);
        //
        //    /* Adjust local account config based on pjsua app config */
        //    {
        //    pjsua_acc_config acc_cfg;
        //    pjsua_acc_get_config(aid, tmp_pool, &acc_cfg);
        //
        //    app_config_init_video(&acc_cfg);
        //    acc_cfg.rtp_cfg = app_config.rtp_cfg;
        //    acc_cfg.ipv6_media_use = PJSUA_IPV6_ENABLED;
        //    pjsua_acc_modify(aid, &acc_cfg);
        //    }
        //
        //    //pjsua_acc_set_transport(aid, transport_id);
        //    pjsua_acc_set_online_status(current_acc, PJ_TRUE);
        //
        //    if (app_config.udp_cfg.port == 0) {
        //    pjsua_transport_info ti;
        //
        //    pjsua_transport_get_info(transport_id, &ti);
        //    tcp_cfg.port = pj_sockaddr_get_port(&ti.local_addr);
        //    }
        //    }
        
        //    /* Add TCP transport unless it's disabled */
        //    if (!app_config.no_tcp) {
        //    pjsua_acc_id aid;
        //
        //    status = pjsua_transport_create(PJSIP_TRANSPORT_TCP,
        //    &tcp_cfg,
        //    &transport_id);
        //    if (status != PJ_SUCCESS)
        //    goto on_error;
        //
        //    /* Add local account */
        //    pjsua_acc_add_local(transport_id, PJ_TRUE, &aid);
        //
        //    /* Adjust local account config based on pjsua app config */
        //    {
        //    pjsua_acc_config acc_cfg;
        //    pjsua_acc_get_config(aid, tmp_pool, &acc_cfg);
        //
        //    app_config_init_video(&acc_cfg);
        //    acc_cfg.rtp_cfg = app_config.rtp_cfg;
        //    pjsua_acc_modify(aid, &acc_cfg);
        //    }
        //
        //    pjsua_acc_set_online_status(current_acc, PJ_TRUE);
        //
        //    }
        //
        //    /* Add TCP IPv6 transport unless it's disabled. */
        //    if (!app_config.no_tcp && app_config.ipv6) {
        //    pjsua_acc_id aid;
        //    pjsip_transport_type_e type = PJSIP_TRANSPORT_TCP6;
        //
        //    tcp_cfg.port += 10;
        //
        //    status = pjsua_transport_create(type,
        //    &tcp_cfg,
        //    &transport_id);
        //    if (status != PJ_SUCCESS)
        //    goto on_error;
        //
        //    /* Add local account */
        //    pjsua_acc_add_local(transport_id, PJ_TRUE, &aid);
        //
        //    /* Adjust local account config based on pjsua app config */
        //    {
        //    pjsua_acc_config acc_cfg;
        //    pjsua_acc_get_config(aid, tmp_pool, &acc_cfg);
        //
        //    app_config_init_video(&acc_cfg);
        //    acc_cfg.rtp_cfg = app_config.rtp_cfg;
        //    acc_cfg.ipv6_media_use = PJSUA_IPV6_ENABLED;
        //    pjsua_acc_modify(aid, &acc_cfg);
        //    }
        //
        //    //pjsua_acc_set_transport(aid, transport_id);
        //    pjsua_acc_set_online_status(current_acc, PJ_TRUE);
        //    }
        
        
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
            
            /* Add local account */
            pjsua_acc_add_local(transport_id, pj_bool_t(PJ_FALSE.rawValue), &acc_id)
            
            /* Adjust local account config based on pjsua app config */
            do {
                var acc_cfg = pjsua_acc_config()
                pjsua_acc_get_config(acc_id, tmp_pool, &acc_cfg)
                
                app_config_init_video(&acc_cfg)
                acc_cfg.rtp_cfg = app_config.rtp_cfg
                pjsua_acc_modify(acc_id, &acc_cfg)
            }
            
            pjsua_acc_set_online_status(acc_id, pj_bool_t(PJ_TRUE.rawValue))
        }
        
        //    /* Add TLS IPv6 transport unless it's disabled. */
        //    if (app_config.use_tls && app_config.ipv6) {
        //    pjsua_acc_id aid;
        //    pjsip_transport_type_e type = PJSIP_TRANSPORT_TLS6;
        //
        //    tcp_cfg.port += 10;
        //
        //    status = pjsua_transport_create(type,
        //    &tcp_cfg,
        //    &transport_id);
        //    if (status != PJ_SUCCESS)
        //    goto on_error;
        //
        //    /* Add local account */
        //    pjsua_acc_add_local(transport_id, PJ_TRUE, &aid);
        //
        //    /* Adjust local account config based on pjsua app config */
        //    {
        //    pjsua_acc_config acc_cfg;
        //    pjsua_acc_get_config(aid, tmp_pool, &acc_cfg);
        //
        //    app_config_init_video(&acc_cfg);
        //    acc_cfg.rtp_cfg = app_config.rtp_cfg;
        //    acc_cfg.ipv6_media_use = PJSUA_IPV6_ENABLED;
        //    pjsua_acc_modify(aid, &acc_cfg);
        //    }
        //
        //    //pjsua_acc_set_transport(aid, transport_id);
        //    pjsua_acc_set_online_status(current_acc, PJ_TRUE);
        //    }
        
        //#endif
        
        if (transport_id == -1) {
            print("Error: no transport is configured")
            status = -1
            pj_pool_release(tmp_pool)
            fatalError()
        }
        
        
        //    /* Add accounts */
        //    for (i=0; i<app_config.acc_cnt; ++i) {
        //    app_config.acc_cfg[i].rtp_cfg = app_config.rtp_cfg;
        //    app_config.acc_cfg[i].reg_retry_interval = 300;
        //    app_config.acc_cfg[i].reg_first_retry_interval = 60;
        //
        //    app_config_init_video(&app_config.acc_cfg[i]);
        //
        //    status = pjsua_acc_add(&app_config.acc_cfg[i], PJ_TRUE, NULL);
        //    if (status != PJ_SUCCESS)
        //    goto on_error;
        //    pjsua_acc_set_online_status(current_acc, PJ_TRUE);
        //    }
        
        //    /* Add buddies */
        //    for (i=0; i<app_config.buddy_cnt; ++i) {
        //    status = pjsua_buddy_add(&app_config.buddy_cfg[i], NULL);
        //    if (status != PJ_SUCCESS) {
        //    PJ_PERROR(1,(THIS_FILE, status, "Error adding buddy"));
        //    goto on_error;
        //    }
        //    }
        
        /* Optionally disable some codec */
        for i in 0..<Int(app_config.codec_dis_cnt) {
            pjsua_codec_set_priority(&app_config.codec_dis[i], pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
            //#if PJSUA_HAS_VIDEO
            pjsua_vid_codec_set_priority(&app_config.codec_dis[i], pj_uint8_t(PJMEDIA_CODEC_PRIO_DISABLED.rawValue))
            //#endif
        }
        
        
        /* Optionally set codec orders */
        for i in 0..<Int(app_config.codec_cnt) {
            pjsua_codec_set_priority(&app_config.codec_arg[i], (pj_uint8_t)(Int(PJMEDIA_CODEC_PRIO_NORMAL.rawValue)+i+9))
            //#if PJSUA_HAS_VIDEO
            pjsua_vid_codec_set_priority(&app_config.codec_arg[i], (pj_uint8_t)(Int(PJMEDIA_CODEC_PRIO_NORMAL.rawValue)+i+9))
            //#endif
        }
        
        /* Use null sound device? */
        //    #ifndef STEREO_DEMO
        if (app_config.null_audio != 0) {
            status = pjsua_set_null_snd_dev()
            if (status != PJ_SUCCESS.rawValue) {
                return status
            }
        }
        //#endif
        
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

enum SIPNotification: String {
    case incomingVideo = "SIPIncomingVideoNotification"
    case callState = "SIPCallStateNotification"
    case registrationState = "SIPRegistrationStateNotification"
    
    var notification: Notification.Name {
        return Notification.Name(rawValue: self.rawValue)
    }
}

var current_call: pjsua_call_id = PJSUA_INVALID_ID.rawValue

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

func on_call_state(_ call_id: pjsua_call_id, _ e: UnsafeMutablePointer<pjsip_event>?) {
    
    var call_info = pjsua_call_info()
    
    //PJ_UNUSED_ARG(e)
    
    pjsua_call_get_info(call_id, &call_info)
    
    if (call_info.state == PJSIP_INV_STATE_DISCONNECTED) {
        
        /* Stop all ringback for this call */
        //ring_stop(call_id)
        
        
        print("Call \(call_id) is DISCONNECTED [reason=\(call_info.last_status) \(call_info.last_status_text.ptr)]")
        
        if (call_id == current_call) {
            _ = find_next_call()
        }
        
        /* Dump media state upon disconnected */
        print("Call \(call_id) disconnected, dumping media stats..")
        
    } else {
        if (call_info.state == PJSIP_INV_STATE_EARLY) {
            
            if current_call == PJSUA_INVALID_ID.rawValue {
                current_call = call_id
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
func on_call_media_state(_ call_id: pjsua_call_id) {
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
                on_call_audio_state(call_info, mi, has_error)
            }
        case PJMEDIA_TYPE_VIDEO:
            on_call_video_state(call_info, mi, has_error)
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

func on_incoming_call(_ acc_id: pjsua_acc_id, _ call_id: pjsua_call_id, _ rdata: UnsafeMutablePointer<pjsip_rx_data>?) {
    var call_info = pjsua_call_info()
    
    //    PJ_UNUSED_ARG(acc_id);
    //    PJ_UNUSED_ARG(rdata);
    
    pjsua_call_get_info(call_id, &call_info)
    
    if current_call == PJSUA_INVALID_ID.rawValue {
        current_call = call_id
    }
    
    /* Start ringback */
    //ring_start(call_id)
    
    //    if (app_config.auto_answer > 0) {
    var opt = pjsua_call_setting()
    
    pjsua_call_setting_default(&opt)
    opt.aud_cnt = app_config.aud_cnt
    opt.vid_cnt = app_config.vid.vid_cnt
    
    pjsua_call_answer2(call_id, &opt, 200/*app_config.auto_answer*/, nil, nil)
    //    }
    
    if (app_config.auto_answer < 200) {
        
        //#if PJSUA_HAS_VIDEO
        if call_info.rem_offerer == pj_bool_t(PJ_TRUE.rawValue), call_info.rem_vid_cnt != 0 {
            print("To \((app_config.vid.vid_cnt != 0 ? "reject" : "accept")) the video, type \"vid \((app_config.vid.vid_cnt != 0 ? "disable" : "enable"))\" first, before answering the call!")
        }
        //#endif
    }
    
    //    dispatch_async(dispatch_get_main_queue(), ^{
    //        [[NSNotificationCenter defaultCenter] postNotificationName:@"SIPIncomingCallNotification" object:nil userInfo:argument];
    //    });
    
}

/* Callback on media events */
func on_call_media_event(_ call_id: pjsua_call_id, _ med_idx: CUnsignedInt, _ event: UnsafeMutablePointer<pjmedia_event>?) {
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
                arrange_window(PJSUA_INVALID_ID.rawValue)
            }
        }
    }
    //    #endif
}

/*
 * Transport status notification
 */
func on_transport_state(_ tp: UnsafeMutablePointer<pjsip_transport>?, _ state: pjsip_transport_state, _ info: UnsafePointer<pjsip_transport_state_info>?) {
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


//func on_call_audio_state(_ ci: pjsua_call_info, _ mi: Int, _ has_error: pj_bool_t) {
//    if ci.media_status == PJSUA_CALL_MEDIA_ACTIVE {
//        pjsua_conf_connect(ci.conf_slot, 0)
//        pjsua_conf_connect(0, ci.conf_slot)
//    }
//}
//
//func on_call_video_state(_ ci: pjsua_call_info, _ mi: Int, _ has_error: pj_bool_t) {
//
////#if true
//    if ci.media_status != PJSUA_CALL_MEDIA_ACTIVE { return }
//
//    var wid: pjsua_vid_win_id = PJSUA_INVALID_ID.rawValue
//    var mediaTuple = ci.media
//
//    let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
//        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
//        let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
//
//        return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
//    }
//
//    wid = media[mi].stream.vid.win_in
//
//    // Incoming video window
//    arrange_window(wid)
////#else
//
//    // Preview window
//    let dev_id = 0
//    var param = pjsua_vid_preview_param()
//
//    pjsua_vid_preview_param_default(&param)
//    param.wnd_flags = PJMEDIA_VID_DEV_WND_BORDER.rawValue | PJMEDIA_VID_DEV_WND_RESIZABLE.rawValue
//    pjsua_vid_preview_start(pjmedia_vid_dev_index(dev_id), &param)
//
//    arrange_window(pjsua_vid_preview_get_win(pjmedia_vid_dev_index(dev_id)))
////#endif
//
//    // Re-invite
////    var para = pjsua_call_vid_strm_op_param()
////    var si = pjsua_stream_info()
////    var status: pj_status_t = pj_status_t(PJ_SUCCESS.rawValue)
////
////    pjsua_call_vid_strm_op_param_default(&para)
//
////    para.med_idx = 0
////    if ((pjsua_call_get_stream_info(ci.id, UInt32(para.med_idx), &si) == PJ_FALSE.rawValue) || si.type != PJMEDIA_TYPE_VIDEO) {
////        return
////    }
//
//    // TODO: pete - only have decoding dir now
////    let dir = si.info.vid.dir
////    para.dir = pjmedia_dir(rawValue: pjmedia_dir.RawValue(UInt8(dir.rawValue) | UInt8(PJMEDIA_DIR_DECODING.rawValue)))
////
////    status = pjsua_call_set_vid_strm(ci.id, PJSUA_CALL_VID_STRM_CHANGE_DIR, &para)
////
////    if status != PJ_SUCCESS.rawValue {
////        fatalError()
////    }
//}

//func onCallMediaState(callID: pjsua_call_id) {
//    var callInfo = pjsua_call_info()
//    let has_error: pj_bool_t = pj_bool_t(PJ_FALSE.rawValue)
//
//    pjsua_call_get_info(callID, &callInfo)
//
//    var mediaTuple = callInfo.media
//    let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
//        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
//        let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
//
//        return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
//    }
//
//    for mi in 0..<Int(callInfo.media_cnt) {
//        switch media[Int(mi)].type {
//        case PJMEDIA_TYPE_AUDIO:
//            on_call_audio_state(callInfo, mi, has_error)
//        case PJMEDIA_TYPE_VIDEO:
//            on_call_video_state(callInfo, mi, has_error)
//        default:
//            /* Make gcc happy about enum not handled by switch/case */
//            break
//        }
//    }
//
//    if has_error == pj_bool_t(PJ_TRUE.rawValue) {
//        var reason: pj_str_t = pj_str(UnsafeMutablePointer<Int8>(mutating: "Media failed"))
//        pjsua_call_hangup(callID, 500, &reason, nil)
//        fatalError()
//    }
//
////    #if PJSUA_HAS_VIDEO
//        /* Check if remote has just tried to enable video */
//        if callInfo.rem_offerer != 0 && callInfo.rem_vid_cnt != 0 {
//            var vid_idx = 0
////            var wid: pjsua_vid_win_id = PJSUA_INVALID_ID.rawValue
//
////            vid_idx = Int(pjsua_call_get_vid_stream_idx(callID))
//
////            if vid_idx >= 0 {
////                // Convert fixed-size C array(Swift treats as tuple) to Swift array.
////                var mediaTuple = callInfo.media
////                let media = withUnsafeBytes(of: &mediaTuple) { (rawPtr) -> [pjsua_call_media_info] in
////                    let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: pjsua_call_media_info.self)
////                    let mediaPointer: UnsafeMutablePointer<pjsua_call_media_info> = UnsafeMutablePointer(mutating: ptr)
////
////                    return Array(UnsafeBufferPointer(start: mediaPointer, count: Int(PJMEDIA_MAX_SDP_MEDIA)))
////                }
////
////                wid = media[vid_idx].stream.vid.win_in
////            }
////
////            print("==Window ID: \(wid)")
//
//
//
//            /* Check if there is active video */
//            vid_idx = Int(pjsua_call_get_vid_stream_idx(callID))
//
//            if vid_idx == -1 || media[vid_idx].dir == PJMEDIA_DIR_NONE {
//                print("Just rejected incoming video offer on call \(callID), use \"vid call enable \(vid_idx)\" or \"vid call add\" to enable video!")
//            }
//        }
////    #endif
//}

func on_reg_state(accountID: pjsua_acc_id) {
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
