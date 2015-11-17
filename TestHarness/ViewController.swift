//
//  ViewController.swift
//  TestHarness
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit
import ConversationKit

class ViewController: UIViewController, UITextFieldDelegate {

	@IBOutlet var nameField: UITextField!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "localSpeakerUpdated:", name: ConversationKit.notifications.localSpeakerUpdated, object: nil)
		// Do any additional setup after loading the view, typically from a nib.
	}

	func localSpeakerUpdated(note: NSNotification) {
		self.nameField.text = Speaker.localSpeaker.name
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@IBAction func buttonTouched(sender: UIButton) {
		
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		self.nameField.text = Speaker.localSpeaker.name
	}
	
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		ConversationKit.instance.setup(localSpeakerName: textField.text)
		return false
	}
}

