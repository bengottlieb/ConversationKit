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
	@IBOutlet var entryContainer: UIView!
	@IBOutlet var tableView: UITableView!
	
	let lastConversationalistKey = "lastConversationalist"
	let speakerIDs = [ "Aurora": "ID:_aceaf3d4cc8dc52f96307ec4374201c5" ]
	var currentConversationalist: Speaker? { didSet {
		if let speaker = self.currentConversationalist {
			let defaults = NSUserDefaults()
			defaults.setObject(speaker.speakerRef, forKey: self.lastConversationalistKey)
			defaults.synchronize()
			self.updateTitle()
		}
	}}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Talk To…", style: .Plain, target: self, action: "chooseConverationalist:")
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateTitle", name: ConversationKit.notifications.localSpeakerUpdated, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "didLoadLocalSpeakers:", name: ConversationKit.notifications.loadedKnownSpeakers, object: nil)

		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)

	}

	//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
	//┃ //MARK: Notifications
	//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

	
	func keyboardWillShow(note: NSNotification) {
		guard let userInfo = note.userInfo as? [String: AnyObject] else { return }
		let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSTimeInterval ?? 0.2
		let curve: UIViewAnimationOptions = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions ?? .CurveEaseOut
		guard let frameHolder = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }
		let finalFrame = frameHolder.CGRectValue()
		let localKeyboardFrame = self.view.convertRect(finalFrame, fromView: nil)
		let heightDelta = self.view.frame.maxY - localKeyboardFrame.origin.y
		var insets = self.tableView.contentInset
		insets.bottom += heightDelta
		
		UIView.animateWithDuration(duration, delay: 0.0, options: [.BeginFromCurrentState, curve], animations: {
			self.entryContainer.transform = CGAffineTransformMakeTranslation(0, -heightDelta)
			self.tableView.contentInset = insets
		}, completion: nil)
	}
	
	func keyboardWillHide(note: NSNotification) {
		guard let userInfo = note.userInfo as? [String: AnyObject] else { return }
		let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSTimeInterval ?? 0.2
		let curve: UIViewAnimationOptions = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions ?? .CurveEaseIn
		var insets = self.tableView.contentInset
		insets.bottom = 0
		
		UIView.animateWithDuration(duration, delay: 0.0, options: [.BeginFromCurrentState, curve], animations: {
			self.entryContainer.transform = CGAffineTransformIdentity
			self.tableView.contentInset = insets
		}, completion: nil)
	}

	func didLoadLocalSpeakers(note: NSNotification) {
		self.currentConversationalist = Speaker.speakerFromSpeakerRef(NSUserDefaults.standardUserDefaults().objectForKey(self.lastConversationalistKey) as? Speaker.SpeakerRef)
	}

	func updateTitle() {
		if let speaker = self.currentConversationalist {
			self.title = "\(Speaker.localSpeaker.name ?? "unnamed") -> \(speaker.name ?? "unnamed")"
		}  else {
			self.title = Speaker.localSpeaker.name
		}
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
			textField.resignFirstResponder()
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
		if !ConversationKit.cloudAvailable { return }
		
		let controller = SelectSpeakerViewController(tag: "tester") { speaker in
			self.currentConversationalist = speaker
		}
		
		controller.title = "Talk to…?"
		self.presentViewController(UINavigationController(rootViewController: controller), animated: true, completion: nil)

	}

}

