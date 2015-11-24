//
//  SpeakerInfoViewController.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/19/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit
import ConversationKit

class SpeakerInfoViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
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

		self.updateAvatarImageButton(self.speaker.avatarImage)
	}

	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	
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

extension SpeakerInfoViewController {
	func updateAvatarImageButton(image: UIImage?) {
		self.avatarButton.setBackgroundImage(image, forState: .Normal)
		self.avatarButton.setTitle(image == nil ? "Select Image" : "", forState: .Normal)
	}
	
	@IBAction func selectAvatarImage(sender: UIButton?) {
		let controller = UIImagePickerController()
		controller.delegate = self
		self.presentViewController(controller, animated: true, completion: nil)
	}
	
	func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		let image = info[UIImagePickerControllerEditedImage] as? UIImage ?? info[UIImagePickerControllerOriginalImage] as? UIImage
		self.updateAvatarImageButton(image)
		self.speaker.storeAvatarImage(image)
		
		picker.dismissViewControllerAnimated(true, completion: nil)
	}
}
