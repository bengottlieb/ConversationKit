//
//  SpeakerInfoViewController.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/19/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit
import ConversationKit

class SpeakerInfoViewController: UIViewController {
	let speaker: Speaker
	
	@IBOutlet var nameField: UITextField!
	@IBOutlet var identifierLabel: UILabel!
	@IBOutlet var avatarButton: UIButton!
	@IBOutlet var tagsField: UITextField!
	
	
	class func showSpeaker(speaker: Speaker, inController: UIViewController) {
		let controller = SpeakerInfoViewController(speaker: speaker)
		inController.presentViewController(UINavigationController(rootViewController: controller), animated: true, completion: nil)
	}
	
	init(speaker spkr: Speaker) {
		speaker = spkr
		super.init(nibName: "SpeakerInfoViewController", bundle: nil)
		
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancel")
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: "save")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.identifierLabel.text = self.speaker.identifier
		self.nameField.text = self.speaker.name
		self.tagsField.text = (Array(self.speaker.tags) as NSArray).componentsJoinedByString(", ")
	}

	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	
	@IBAction func selectAvatarImage(sender: UIButton?) {
		
	}
	
	@IBAction func save() {
		self.speaker.name = self.nameField.text
		self.speaker.tags = Set(self.tagsField.text?.componentsSeparatedByString(",").map({ $0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) }) ?? [])
		self.view.alpha = 0.25
		self.view.userInteractionEnabled = false
		self.speaker.save { success in
			
			if success {
				self.dismissViewControllerAnimated(true, completion: nil)
			} else {
				self.view.alpha = 1.0
				self.view.userInteractionEnabled = true
			}
		}
	}
	
	@IBAction func cancel() {
		self.dismissViewControllerAnimated(true, completion: nil)
	}
	
}
