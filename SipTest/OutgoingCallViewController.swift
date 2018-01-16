//
//  OutgoingCallViewController.swift
//  SipTest
//
//  Created by Zhe Cui on 12/18/17.
//  Copyright © 2017 Zhe Cui. All rights reserved.
//

import UIKit
import AVFoundation

class OutgoingCallViewController: UIViewController {

    @IBOutlet weak var calleeTextField: UITextField!
    @IBOutlet weak var callButton: UIButton!
    
    var callID = pjsua_call_id()
    var videoOn = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleCallStatusChanged), name: SIPNotification.callState.notification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleIncomingVideo), name: SIPNotification.incomingVideo.notification, object: nil)
        
        switch AVAudioSession.sharedInstance().recordPermission() {
        case AVAudioSessionRecordPermission.granted:
            print("Permission granted")
        case AVAudioSessionRecordPermission.denied:
            print("Pemission denied")
        case AVAudioSessionRecordPermission.undetermined:
            print("Request permission here")
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                // Handle granted
            })
        }
    }

    @objc func handleCallStatusChanged(_ notification: Notification) {
        let callID: pjsua_call_id = notification.userInfo!["callID"] as! pjsua_call_id
        let state: pjsip_inv_state = notification.userInfo!["state"] as! pjsip_inv_state
        
        if callID != self.callID {
            print("Incorrect Call ID.")
            return
        }
        
        if state == PJSIP_INV_STATE_DISCONNECTED {
            callButton.setTitle("Call", for: .normal)
        } else if state == PJSIP_INV_STATE_CONNECTING {
            print("Call connecting...")
        } else if state == PJSIP_INV_STATE_CONFIRMED {
            callButton.setTitle("Hangup", for: .normal)
        }
    }
    
    @IBAction func tapToCallOrHangup(_ sender: UIButton) {
        if sender.title(for: .normal) == "Call" {
            makeCall()
        } else if sender.title(for: .normal) == "Hangup" {
            hangup()
        } else {
            fatalError()
        }
    }
    
    @IBAction func tapToStartVideo(_ sender: UIButton) {
//        var callInfo = pjsua_call_info()
//        pjsua_call_get_info(callID, &callInfo)
        callID = 1

        var status = pj_status_t(PJ_SUCCESS.rawValue)
        var param = pjsua_call_vid_strm_op_param()
        
        videoOn = videoOn ? false : true
        let videoOp = videoOn ? PJSUA_CALL_VID_STRM_START_TRANSMIT : PJSUA_CALL_VID_STRM_STOP_TRANSMIT
        
//        videoOp = PJSUA_CALL_VID_STRM_CHANGE_DIR
        
        pjsua_call_vid_strm_op_param_default(&param)
        param.med_idx = -1 // First active video stream
        
        status = pjsua_call_set_vid_strm(callID, videoOp, &param)
        
        if status != pj_status_t(PJ_SUCCESS.rawValue) {
            fatalError()
        }
    }
    
    private func makeCall() {
        let accountID: pjsua_acc_id = pjsua_acc_id(UserDefaults.standard.integer(forKey: "loginAccountID"))
        let serverURI: String = UserDefaults.standard.string(forKey: "serverURI")!
        
        let destinationURI = "sip:\(calleeTextField.text!)@\(serverURI)"
        
        var status = pj_status_t()
        var calleeURI: pj_str_t = pj_str(UnsafeMutablePointer<Int8>(mutating: (destinationURI as NSString).utf8String))
        
        status = pjsua_call_make_call(accountID, &calleeURI, nil, nil, nil, &callID)
        
        if status != PJ_SUCCESS.rawValue {
            var errorMessage: [CChar] = []
            
            pj_strerror(status, &errorMessage, pj_size_t(PJ_ERR_MSG_SIZE))
            print("Outgoing call error, status: \(status), message: \(errorMessage)")
            fatalError()
        }
    }
    
    private func hangup() {
        let status = pjsua_call_hangup(callID, 0, nil, nil)
        
        if status != PJ_SUCCESS.rawValue {
            let statusText: UnsafePointer<pj_str_t> = pjsip_get_status_text(status)
            print("Hangup error, status: \(status), message: \(statusText.pointee)")
        }
    }

    @objc func handleIncomingVideo(_ notification: Notification) {
        //let callID: pjsua_call_id = notification.userInfo!["callID"] as! pjsua_call_id
        //let phoneNumber: String = notification.userInfo!["remoteAddress"] as! String
        let windowID: pjsua_vid_win_id = notification.userInfo!["windowID"] as! pjsua_vid_win_id

        performSegue(withIdentifier: "segueOutgoingCallToIncomingVideo", sender: (windowID))
    }
    
    // Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueOutgoingCallToIncomingVideo" {
            let destinationVC = segue.destination as! IncomingCallViewController
            
            let param = sender as! pjsua_vid_win_id
            destinationVC.setParam(param)
        }
    }
    
    @IBAction func unwindToOutgoingCall(segue: UIStoryboardSegue) {
    
    }
    
}
