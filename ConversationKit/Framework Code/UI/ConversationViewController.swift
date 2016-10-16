//
//  ConversationViewController.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/24/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

open class ConversationViewController: UIViewController {
	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	open var sendButtonEnabledColor = UIColor.blue
	open var sendButtonDisabledColor = UIColor.lightGray
	
	@IBOutlet open var messageField: UITextField!
	@IBOutlet open var entryContainer: UIView!
	@IBOutlet open var sendButton: UIButton!
	@IBOutlet open var conversationView: ConversationView!
	
	open var currentConversation: Conversation? {
		set {
			self.conversationView?.conversation?.isVisible = false
			self.conversationView?.conversation = newValue
			self.updateUI()
			self.didChangeConversation()
			newValue?.isVisible = true
		}
		get { return self.conversationView?.conversation }
	}

	public convenience init?(remoteID: String?) {
		guard let id = remoteID else {
			self.init(nibName: "ConversationViewController", bundle: Bundle(for: ConversationKit.self))
			return nil
		}
		
		self.init(remoteSpeaker: Speaker.speaker(withIdentifier: id))
	}
	
	public convenience init?(remoteSpeaker: Speaker?) {
		guard let speaker = remoteSpeaker, let localSpeaker = Speaker.localSpeaker else {
			self.init(nibName: "ConversationViewController", bundle: Bundle(for: ConversationKit.self))
			return nil
		}
		
		let convo = localSpeaker.conversation(with: speaker)
		self.init(conversation: convo)
	}
	
	public convenience init(conversation: Conversation?) {
		self.init(nibName: "ConversationViewController", bundle: Bundle(for: ConversationKit.self))
		self.edgesForExtendedLayout  = UIRectEdge()
		self.loadViewIfNeeded()
		if let convo = conversation {
			self.conversationView.conversation = convo
		}
		self.updateUI()
	}
	
	open override func viewDidLoad() {
		super.viewDidLoad()
		
		self.sendButton.setTitleColor(self.sendButtonEnabledColor, for: UIControlState())
		self.sendButton.setTitleColor(self.sendButtonDisabledColor, for: .disabled)
		
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationViewController.updateUI), name: NSNotification.Name(rawValue: ConversationKit.notifications.localSpeakerUpdated), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationViewController.receivedMessage(_:)), name: NSNotification.Name(rawValue: ConversationKit.notifications.postedNewMessage), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationViewController.conversationSelected(_:)), name: NSNotification.Name(rawValue: ConversationKit.notifications.conversationSelected), object: nil)
		
		
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
	}
	
	open func didChangeConversation() {}
	
	//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
	//┃ //MARK: Notifications
	//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
	
	func conversationSelected(_ note: Notification) {
		if let convo = note.object as? Conversation, let current = self.currentConversation , convo != current {
			self.currentConversation = convo
		}
	}
	
	func receivedMessage(_ note: Notification) {
		if let message = note.object as? Message, let convo = message.conversation , self.currentConversation == nil {
			self.currentConversation = convo
		}
	}
	
	func keyboardWillShow(_ note: Notification) {
		guard let userInfo = (note as NSNotification).userInfo as? [String: AnyObject] else { return }
		let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.2
		let curve: UIViewAnimationOptions = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions ?? .curveEaseOut
		guard let frameHolder = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }
		let finalFrame = frameHolder.cgRectValue
		let localKeyboardFrame = self.view.convert(finalFrame, from: nil)
		let heightDelta = self.entryContainer.frame.maxY - localKeyboardFrame.origin.y
		var insets = self.conversationView.contentInset
		insets.bottom += heightDelta
		
		UIView.animate(withDuration: duration, delay: 0.0, options: [.beginFromCurrentState, curve], animations: {
			self.entryContainer.transform = CGAffineTransform(translationX: 0, y: -(heightDelta - self.entryContainer.transform.ty))
			self.conversationView.contentInset = insets
		}, completion: nil)
	}
	
	func keyboardWillHide(_ note: Notification) {
		guard let userInfo = (note as NSNotification).userInfo as? [String: AnyObject] else { return }
		let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.2
		let curve: UIViewAnimationOptions = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UIViewAnimationOptions ?? .curveEaseIn
		var insets = self.conversationView.contentInset
		insets.bottom = 0
		
		UIView.animate(withDuration: duration, delay: 0.0, options: [.beginFromCurrentState, curve], animations: {
			self.entryContainer.transform = CGAffineTransform.identity
			self.conversationView.contentInset = insets
			}, completion: nil)
	}
	
	func updateUI() {
		if let convo = self.currentConversation, let name = convo.nonLocalSpeaker.name {
			self.title = name
		}
		
		let returnKeyType: UIReturnKeyType
		if let text = self.messageField?.text , !text.isEmpty {
			returnKeyType = .send
		} else {
			returnKeyType = .done
		}
		
		if self.messageField.returnKeyType != returnKeyType {
			self.messageField.returnKeyType = returnKeyType
			self.messageField.reloadInputViews()
		}
		
		self.messageField?.isEnabled = self.currentConversation != nil
		self.sendButton?.isEnabled = self.currentConversation != nil && !(self.messageField?.text ?? "").isEmpty
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if textField == self.messageField {
			textField.resignFirstResponder()
			if let text = textField.text , !text.isEmpty {
				self.sendMessage()
			}
		}
		return false
	}
	
	func updatePendingIndicator() {
		self.currentConversation?.hasPendingOutgoingMessage = !(self.messageField?.text?.isEmpty ?? true)
	}
	
	@IBAction func textFieldChanged(_ field: UITextField?) {
		self.updatePendingIndicator()
		self.updateUI()
	}
	
	@IBAction func sendMessage() {
		if let text = self.messageField.text, let speaker = self.currentConversation?.nonLocalSpeaker , text.characters.count > 0 {
			self.currentConversation?.hasPendingOutgoingMessage = false
			speaker.send(message: text) { saved in
				print("message saved: \(saved)")
			}
			
			self.messageField.text = ""
			self.updateUI()
		}
	}
}
