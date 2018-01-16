//
//  ViewController.swift
//  SipTest
//
//  Created by Zhe Cui on 12/17/17.
//  Copyright © 2017 Zhe Cui. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var serverURITextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    var videoOn = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(tapToDismissKeyboard)))
        
        serverURITextField.text = "siptest.butterflymx.com"
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRegistrationStatus), name: SIPNotification.registrationState.notification, object: nil)        
    }
    
//    @objc func tapToDismissKeyboard() {
//        view.endEditing(true)
//    }
    
    func switchOutgoingVideo(_ on: Bool) -> pj_status_t {
        var status = pj_status_t(PJ_SUCCESS.rawValue)
        var param = pjsua_call_vid_strm_op_param()
        var si = pjsua_stream_info()
        let callID: pjsua_call_id = 1 // TODO: Get call ID
        
        pjsua_call_vid_strm_op_param_default(&param)

        param.med_idx = 1 // TODO: Get video stream index
        if (pjsua_call_get_stream_info(callID, UInt32(param.med_idx), &si) != PJ_SUCCESS.rawValue || si.type != PJMEDIA_TYPE_VIDEO) {
            print("Invalid stream")
            return status
        }

        let defaultDir = si.info.vid.dir
        let dir = on ? (defaultDir.rawValue | PJMEDIA_DIR_ENCODING.rawValue) : (defaultDir.rawValue & PJMEDIA_DIR_DECODING.rawValue)
        
        param.dir = pjmedia_dir(rawValue: dir)
        
        status = pjsua_call_set_vid_strm(callID, PJSUA_CALL_VID_STRM_CHANGE_DIR, &param)
        
        return status
    }
    
    @IBAction func tapVideoButton(_ sender: UIButton) {
        var status = pj_status_t(PJ_SUCCESS.rawValue)
        
        videoOn = videoOn ? false : true
        
        status = switchOutgoingVideo(videoOn)
        if status != pj_status_t(PJ_SUCCESS.rawValue) {
            fatalError()
        }
    }
    
    @IBAction func tapLoginButton(_ sender: UIButton) {
        var accountID = pjsua_acc_id()
        var accountConfig = pjsua_acc_config()
        
        pjsua_acc_config_default(&accountConfig)
        
        let fullURL = ("sip:\(usernameTextField.text!)@\(serverURITextField.text!)" as NSString).utf8String
        // Always use "sips" for server
        let uri = ("sips:\(serverURITextField.text!)" as NSString).utf8String
        let realm = ("\(serverURITextField.text!)" as NSString).utf8String
        let username = ("\(usernameTextField.text!)" as NSString).utf8String
        var password = ("\(passwordTextField.text!)" as NSString).utf8String

        // Bypass password for test use.
        if usernameTextField.text! == "6728" {
            password = ("123456" as NSString).utf8String!
            passwordTextField.text = String(cString: password!)
        }
        
        if usernameTextField.text! == "panel_4" {
            password = ("123" as NSString).utf8String!
            passwordTextField.text = String(cString: password!)
        }
        
        accountConfig.id = pj_str(UnsafeMutablePointer<Int8>(mutating: fullURL))
        accountConfig.reg_uri = pj_str(UnsafeMutablePointer<Int8>(mutating: uri))
        accountConfig.reg_retry_interval = 0
        accountConfig.cred_count = 1
        accountConfig.cred_info.0.realm = pj_str(UnsafeMutablePointer<Int8>(mutating: realm))
        accountConfig.cred_info.0.username = pj_str(UnsafeMutablePointer<Int8>(mutating: username))
        accountConfig.cred_info.0.data_type = Int32(PJSIP_CRED_DATA_PLAIN_PASSWD.rawValue)
        accountConfig.cred_info.0.data = pj_str(UnsafeMutablePointer<Int8>(mutating: password))
  
        // Show incoming video
        accountConfig.vid_in_auto_show = pj_bool_t(PJ_TRUE.rawValue)
        accountConfig.vid_out_auto_transmit = pj_bool_t(PJ_TRUE.rawValue)
        accountConfig.vid_wnd_flags = PJMEDIA_VID_DEV_WND_BORDER.rawValue | PJMEDIA_VID_DEV_WND_RESIZABLE.rawValue
        accountConfig.vid_cap_dev = PJMEDIA_VID_DEFAULT_CAPTURE_DEV.rawValue
        accountConfig.vid_rend_dev = PJMEDIA_VID_DEFAULT_RENDER_DEV.rawValue

        
        let status: pj_status_t = pjsua_acc_add(&accountConfig, pj_bool_t(PJ_TRUE.rawValue), &accountID)
        
        if status != PJ_SUCCESS.rawValue {
            print("Register error, status: \(status)")
        }
        
        // Show incoming video
//        accountConfig.vid_in_auto_show = pj_bool_t(PJ_TRUE.rawValue)
//        accountConfig.vid_out_auto_transmit = pj_bool_t(PJ_TRUE.rawValue)
        
//        accountConfig.vid_wnd_flags = PJMEDIA_VID_DEV_WND_BORDER.rawValue | PJMEDIA_VID_DEV_WND_RESIZABLE.rawValue
//        accountConfig.vid_cap_dev = PJMEDIA_VID_DEFAULT_CAPTURE_DEV.rawValue
//        accountConfig.vid_rend_dev = 0
    }
    
    @objc func handleRegistrationStatus(_ notification: Notification) {
        let accountID: pjsua_acc_id = notification.userInfo!["accountID"] as! pjsua_acc_id
        let status: pjsip_status_code = notification.userInfo!["status"] as! pjsip_status_code
        let statusText: String = notification.userInfo!["statusText"] as! String
        
        if status != PJSIP_SC_OK {
            print("Registration failed, status: \(status, statusText) ")
            
            return
        }
        
        UserDefaults.standard.set(accountID, forKey: "loginAccountID")
        UserDefaults.standard.set(self.serverURITextField.text, forKey: "serverURI")
        UserDefaults.standard.synchronize()
        
        performSegue(withIdentifier: "segueLoginToOutgoingCall", sender: self)
    }

}

