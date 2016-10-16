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
	
	
	class func showSpeaker(_ speaker: Speaker, inController: UIViewController) {
		let controller = SpeakerInfoViewController(speaker: speaker)
		inController.present(UINavigationController(rootViewController: controller), animated: true, completion: nil)
	}
	
	init(speaker spkr: Speaker) {
		speaker = spkr
		super.init(nibName: "SpeakerInfoViewController", bundle: nil)
		
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(SpeakerInfoViewController.cancel))
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(SpeakerInfoViewController.save))
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.identifierLabel.text = self.speaker.identifier
		self.nameField.text = self.speaker.name
		self.tagsField.text = (Array(self.speaker.tags) as NSArray).componentsJoined(by: ", ")

		self.updateAvatarImageButton(self.speaker.avatarImage)
	}

	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	
	@IBAction func save() {
		self.speaker.name = self.nameField.text
		self.speaker.tags = Set(self.tagsField.text?.components(separatedBy: ",").map({ $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }) ?? [])
		self.view.alpha = 0.25
		self.view.isUserInteractionEnabled = false
		self.speaker.save { error in
			
			if error == nil {
				self.dismiss(animated: true, completion: nil)
			} else {
				self.view.alpha = 1.0
				self.view.isUserInteractionEnabled = true
			}
		}
	}
	
	@IBAction func cancel() {
		self.dismiss(animated: true, completion: nil)
	}
	
}

extension SpeakerInfoViewController {
	func updateAvatarImageButton(_ image: UIImage?) {
		self.avatarButton.setBackgroundImage(image, for: UIControlState())
		self.avatarButton.setTitle(image == nil ? "Select Image" : "", for: UIControlState())
	}
	
	@IBAction func selectAvatarImage(_ sender: UIButton?) {
		let controller = UIImagePickerController()
		controller.delegate = self
		self.present(controller, animated: true, completion: nil)
	}
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		let image = info[UIImagePickerControllerEditedImage] as? UIImage ?? info[UIImagePickerControllerOriginalImage] as? UIImage
		self.updateAvatarImageButton(image)
		self.speaker.store(avatar: image)
		
		picker.dismiss(animated: true, completion: nil)
	}
}
