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

	@IBOutlet var messageField: UITextField!
	
	let speakerIDs = [ "Aurora": "ID:_aceaf3d4cc8dc52f96307ec4374201c5" ]
	var currentConversationalist: Speaker?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Talk To…", style: .Plain, target: self, action: "chooseConverationalist:")
		
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "localSpeakerUpdated:", name: ConversationKit.notifications.localSpeakerUpdated, object: nil)
		// Do any additional setup after loading the view, typically from a nib.
	}

	func localSpeakerUpdated(note: NSNotification) {
		self.title = Speaker.localSpeaker.name
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
	}
	
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		if textField == self.messageField {
			if let text = textField.text where text != "" {
				self.currentConversationalist?.sendMessage(text) { saved in
					print("message saved: \(saved)")
				}
				textField.text = ""
			}
		}
		return false
	}
	
	@IBAction func showSpeakerInfo() {
		SpeakerInfoViewController.showSpeaker(Speaker.localSpeaker, inController: self)
	}

	@IBAction func sendMessage() {
		if let text = self.messageField.text, speaker = self.currentConversationalist where text.characters.count > 0 {
			speaker.sendMessage(text) { saved in
				print("message saved: \(saved)")
			}
			self.messageField.text = ""
		}
	}
	
	@IBAction func chooseConverationalist(sender: UIButton?) {
		if !Cloud.instance.configured { return }
		
		let controller = SelectSpeakerViewController(tag: "tester") { speaker in
			self.currentConversationalist = speaker
		}
		
		controller.title = "Talk to…?"
		self.presentViewController(UINavigationController(rootViewController: controller), animated: true, completion: nil)

	}

}

