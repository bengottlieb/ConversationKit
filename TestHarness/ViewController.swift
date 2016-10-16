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
		
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Talk To…", style: .plain, target: self, action: #selector(TestViewController.chooseConverationalist))
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Info", style: .plain, target: self, action: #selector(TestViewController.showSpeakerInfo))
		
		NotificationCenter.default.addObserver(self, selector: #selector(TestViewController.didLoadLocalSpeakers(_:)), name: ConversationKit.notifications.loadedKnownSpeakers, object: nil)
	}
	
	override func didChangeConversation() {
		if let speaker = self.currentConversation?.nonLocalSpeaker {
			let defaults = UserDefaults()
			defaults.set(speaker.speakerRef, forKey: self.lastConversationalistKey)
			defaults.synchronize()
			self.navigationItem.rightBarButtonItem = self.currentConversation?.createBarButtonItem(target: self, action: #selector(TestViewController.chooseConverationalist))
		}
	}
	

	//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
	//┃ //MARK: Notifications
	//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

	func didLoadLocalSpeakers(_ note: Notification) {
		if let speaker = Speaker.speaker(fromRef: UserDefaults.standard.object(forKey: self.lastConversationalistKey) as? Speaker.SpeakerRef), let localSpeaker = Speaker.localSpeaker {
			self.currentConversation = Conversation.conversationBetween([speaker, localSpeaker])
		}
	}
	
	@IBAction func showSpeakerInfo() {
		SpeakerInfoViewController.showSpeaker(Speaker.localSpeaker, inController: self)
	}
	
	@IBAction func chooseConverationalist(_ sender: UIButton?) {
		if !ConversationKit.cloudAvailable { return }
		
		let controller = SelectSpeakerViewController(tag: "tester") { speaker in
			if let speaker = speaker, let localSpeaker = Speaker.localSpeaker {
				self.currentConversation = Conversation.conversationBetween([speaker, localSpeaker])
			}
		}
		
		controller.title = Speaker.localSpeaker?.name ?? "Unnamed"
		self.present(UINavigationController(rootViewController: controller), animated: true, completion: nil)

	}

}
