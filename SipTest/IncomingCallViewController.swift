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
    private var phoneNumber = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        incomingCallLabel.text = "\(callID): \(phoneNumber)"
        NotificationCenter.default.addObserver(self, selector: #selector(handleCallStatusChanged), name: SIPNotification.callState.notification, object: nil)
    }
    
    func setParam(_ callID: pjsua_call_id, _ phoneNumber: String) {
        self.callID = callID
        self.phoneNumber = phoneNumber
    }

    @objc func handleCallStatusChanged(_ notification: Notification) {
        let callID: pjsua_call_id = notification.userInfo!["callID"] as! pjsua_call_id
        let state: pjsip_inv_state = notification.userInfo!["state"] as! pjsip_inv_state
        
        if callID != self.callID {
            print("Incorrect Call ID.")
            return
        }
        
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
