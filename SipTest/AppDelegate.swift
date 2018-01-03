//
//  AppDelegate.swift
//  SipTest
//
//  Created by Zhe Cui on 12/17/17.
//  Copyright © 2017 Zhe Cui. All rights reserved.
//

import UIKit
import PushKit
import Darwin

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
        pjsuaConfig.outbound_proxy.0 = pj_str(UnsafeMutablePointer<Int8>(mutating: ("sips:siptest.butterflymx.com:5061" as NSString).utf8String))

        
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

        // Get sound devices
        status = pjsua_get_snd_dev(&captureDeviceID, &playbackDeviceID)
        if status != PJ_SUCCESS.rawValue {
            print("Error get sound dev IDs, status: \(status)")
            fatalError()
        }

        // Disconnect sound devices
        pjsua_set_no_snd_dev()
        
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

