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
	@IBOutlet var messageField: UITextField!
	
	let speakerIDs = [ "Aurora": "ID:_aceaf3d4cc8dc52f96307ec4374201c5" ]
	var currentConversationalist: Speaker?
	
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
		if let name = sender.titleLabel?.text, speakerID = self.speakerIDs[name] {
			self.currentConversationalist = Speaker.speakerWithIdentifier(speakerID, name: name)
			
			sender.backgroundColor = UIColor.blueColor()
			sender.setTitleColor(UIColor.whiteColor(), forState: .Normal)
		}
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		self.nameField.text = Speaker.localSpeaker?.name
	}
	
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		if textField == self.nameField {
			Speaker.localSpeaker.name = textField.text
			Speaker.localSpeaker.save()
		} else if textField == self.messageField {
			if let text = textField.text where text != "" {
				self.currentConversationalist?.sendMessage(text) { saved in
					print("message saved: \(saved)")
				}
				textField.text = ""
			}
		}
		return false
	}
}

