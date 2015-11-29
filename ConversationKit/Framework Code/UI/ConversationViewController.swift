//
//  ConversationViewController.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/24/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

public class ConversationViewController: UIViewController {
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	public var sendButtonEnabledColor = UIColor.blueColor()
	public var sendButtonDisabledColor = UIColor.lightGrayColor()
	
	@IBOutlet public var messageField: UITextField!
	@IBOutlet public var entryContainer: UIView!
	@IBOutlet public var sendButton: UIButton!
	@IBOutlet public var conversationView: ConversationView!
	
	public var currentConversation: Conversation? {
		set {
			self.conversationView?.conversation = newValue
			self.updateUI()
			self.didChangeConversation()
		}
		get { return self.conversationView?.conversation }
	}
	
	public convenience init(conversation: Conversation?) {
		self.init(nibName: "ConversationViewController", bundle: NSBundle(forClass: ConversationKit.self))
		self.edgesForExtendedLayout  = .None
		self.loadViewIfNeeded()
		if let convo = conversation {
			self.conversationView.conversation = convo
		}
		self.updateUI()
	}
	
	public override func viewDidLoad() {
		super.viewDidLoad()
		
		self.sendButton.setTitleColor(self.sendButtonEnabledColor, forState: .Normal)
		self.sendButton.setTitleColor(self.sendButtonDisabledColor, forState: .Disabled)
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateUI", name: ConversationKit.notifications.localSpeakerUpdated, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedMessage:", name: ConversationKit.notifications.postedNewMessage, object: nil)
		
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
	}
	
	public func didChangeConversation() {}
	
	//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
	//┃ //MARK: Notifications
	//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
	
	func receivedMessage(note: NSNotification) {
		if let message = note.object as? Message, convo = message.conversation where self.currentConversation == nil {
			self.currentConversation = convo
		}
	}
	
	func keyboardWillShow(note: NSNotification) {
		guard let userInfo = note.userInfo as? [String: AnyObject] else { return }
		let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSTimeInterval ?? 0.2
		let curve: UIViewAnimationOptions = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions ?? .CurveEaseOut
		guard let frameHolder = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }
		let finalFrame = frameHolder.CGRectValue()
		let localKeyboardFrame = self.view.convertRect(finalFrame, fromView: nil)
		let heightDelta = self.view.frame.maxY - localKeyboardFrame.origin.y
		var insets = self.conversationView.contentInset
		insets.bottom += heightDelta
		
		UIView.animateWithDuration(duration, delay: 0.0, options: [.BeginFromCurrentState, curve], animations: {
			self.entryContainer.transform = CGAffineTransformMakeTranslation(0, -heightDelta)
			self.conversationView.contentInset = insets
		}, completion: nil)
	}
	
	func keyboardWillHide(note: NSNotification) {
		guard let userInfo = note.userInfo as? [String: AnyObject] else { return }
		let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSTimeInterval ?? 0.2
		let curve: UIViewAnimationOptions = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions ?? .CurveEaseIn
		var insets = self.conversationView.contentInset
		insets.bottom = 0
		
		UIView.animateWithDuration(duration, delay: 0.0, options: [.BeginFromCurrentState, curve], animations: {
			self.entryContainer.transform = CGAffineTransformIdentity
			self.conversationView.contentInset = insets
			}, completion: nil)
	}
	
	func updateUI() {
		if let convo = self.currentConversation {
			self.title = convo.nonLocalSpeaker.name
		} else {
			self.title = ""
		}
		self.messageField?.enabled = self.currentConversation != nil
		self.sendButton?.enabled = self.currentConversation != nil && !(self.messageField?.text ?? "").isEmpty
	}
	
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		if textField == self.messageField {
			textField.resignFirstResponder()
		}
		return false
	}
	
	@IBAction func textFieldChanged(field: UITextField?) {
		self.updateUI()
	}
	
	@IBAction func sendMessage() {
		if let text = self.messageField.text, speaker = self.currentConversation?.nonLocalSpeaker where text.characters.count > 0 {
			speaker.sendMessage(text) { saved in
				print("message saved: \(saved)")
			}
			self.messageField.text = ""
		}
	}
}
