//
//  ViewController.swift
//  TestHarness
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit
import ConversationKit

class TestViewController: ConversationViewController {
	let lastConversationalistKey = "lastConversationalist"
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Talk To…", style: .Plain, target: self, action: "chooseConverationalist:")
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Info", style: .Plain, target: self, action: "showSpeakerInfo")
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "didLoadLocalSpeakers:", name: ConversationKit.notifications.loadedKnownSpeakers, object: nil)
	}
	
	override func didChangeConversation() {
		if let speaker = self.currentConversation?.nonLocalSpeaker {
			let defaults = NSUserDefaults()
			defaults.setObject(speaker.speakerRef, forKey: self.lastConversationalistKey)
			defaults.synchronize()
		}
	}
	

	//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
	//┃ //MARK: Notifications
	//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

	func didLoadLocalSpeakers(note: NSNotification) {
		if let speaker = Speaker.speakerFromSpeakerRef(NSUserDefaults.standardUserDefaults().objectForKey(self.lastConversationalistKey) as? Speaker.SpeakerRef) {
			self.currentConversation = Conversation.conversationWith(speaker)
		}
	}
	
	@IBAction func showSpeakerInfo() {
		SpeakerInfoViewController.showSpeaker(Speaker.localSpeaker, inController: self)
	}
	
	@IBAction func chooseConverationalist(sender: UIButton?) {
		if !ConversationKit.cloudAvailable { return }
		
		let controller = SelectSpeakerViewController(tag: "tester") { speaker in
			if let speaker = speaker {
				self.currentConversation = Conversation.conversationWith(speaker)
			}
		}
		
		controller.title = "Talk to…?"
		self.presentViewController(UINavigationController(rootViewController: controller), animated: true, completion: nil)

	}

}
