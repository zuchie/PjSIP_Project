//
//  IncomingCallViewController.swift
//  SipTest
//
//  Created by Zhe Cui on 12/18/17.
//  Copyright © 2017 Zhe Cui. All rights reserved.
//

import UIKit

class IncomingCallViewController: UIViewController {

    @IBOutlet weak var incomingCallLabel: UILabel!
    
    private var callID = pjsua_call_id()
    //private var phoneNumber = ""
    private var windowID = pjsua_vid_win_id()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //incomingCallLabel.text = "\(callID): \(phoneNumber)"
        NotificationCenter.default.addObserver(self, selector: #selector(handleCallStatusChanged), name: SIPNotification.callState.notification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //displayWindow(windowID)
    }
    
    func setParam(_ windowID: pjsua_vid_win_id) {
//        self.callID = callID
//        self.phoneNumber = phoneNumber
        self.windowID = windowID
    }

    @objc func handleCallStatusChanged(_ notification: Notification) {
        let callID: pjsua_call_id = notification.userInfo!["callID"] as! pjsua_call_id
        let state: pjsip_inv_state = notification.userInfo!["state"] as! pjsip_inv_state
        
        self.callID = callID
        
//        if callID != self.callID {
//            print("Incorrect Call ID.")
//            return
//        }
        
        if state == PJSIP_INV_STATE_DISCONNECTED {
            print("Call disconnected")
            performSegue(withIdentifier: "unwindToOutgoingCall", sender: self)
        } else if state == PJSIP_INV_STATE_CONNECTING {
            print("Call connecting...")
        } else if state == PJSIP_INV_STATE_CONFIRMED {
            print("Call connected")
        }
    }
    
    @IBAction func tapToAnswer(_ sender: UIButton) {
        pjsua_call_answer(self.callID, 200, nil, nil)
    }
    
    @IBAction func tapToHangup(_ sender: UIButton) {
        pjsua_call_hangup(self.callID, 0, nil, nil)
    }
    
//    func displayWindow(_ wid: pjsua_vid_win_id) {
//        //#if PJSUA_HAS_VIDEO
//        var i: CInt = 0
//        var last: CInt = 0
//
//        i = (wid == PJSUA_INVALID_ID.rawValue) ? 0 : wid
//        last = (wid == PJSUA_INVALID_ID.rawValue) ? PJSUA_MAX_VID_WINS : wid + 1
//
//        while i < last {
//            var wi = pjsua_vid_win_info()
//
//            if (pjsua_vid_win_get_info(i, &wi) == PJ_SUCCESS.rawValue) {
//                //  C UnsafeMutableRawPointer to Swift Object
//                let videoView = Unmanaged<UIView>.fromOpaque(wi.hwnd.info.ios.window).takeUnretainedValue()
//
//                DispatchQueue.main.async {
//                    /* Add the video window as subview */
//                    videoView.isHidden = false
//                    self.view.addSubview(videoView)
//
//                    if wi.is_native == PJ_FALSE.rawValue {
//                        /* Resize it to fit width */
//                        videoView.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height * 1.0 * self.view.bounds.size.width / videoView.bounds.size.width)
//                        /* Center it horizontally */
//                        videoView.center = CGPoint(x: self.view.bounds.size.width / 2.0, y: videoView.bounds.size.height / 2.0)
//                    } else {
//                        /* Preview window, move it to the bottom */
//                        videoView.center = CGPoint(x: self.view.bounds.size.width / 2.0, y: self.view.bounds.size.height - videoView.bounds.size.height / 2.0)
//                    }
//                }
//            }
//
//            i += 1
//        }
//        //#endif
//    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
