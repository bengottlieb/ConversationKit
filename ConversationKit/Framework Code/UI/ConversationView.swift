//
//  ConversationMessagesTableView.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/23/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

public class ConversationView: UIView {
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	public var conversation: Conversation? { didSet {
		self.loadTable()
		self.scrollToLast()
	}}
	public var allowMessageDeletion = true
	var tableView: UITableView!
	var messages: [Message] = []
	var notSignedInLabel: UILabel!
	var openSettingsButton: UIButton!
	
	public override init(frame: CGRect) {
		super.init(frame: frame)
		self.setup()
	}
	
	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.setup()
	}
	
	func setup() {
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "scrollToLast", name: ConversationKit.notifications.finishedLoadingMessagesForConversation, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "newMessage:", name: ConversationKit.notifications.postedNewMessage, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateUI", name: ConversationKit.notifications.downloadedOldMessage, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateUI", name: ConversationKit.notifications.iCloudAccountIDChanged, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "pendingStatusChanged:", name: ConversationKit.notifications.incomingPendingMessageChanged, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "conversationWasDeleted:", name: ConversationKit.notifications.conversationDeleted, object: nil)
		
		self.updateUI()
	}
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		self.loadTable()
	}
	
	func conversationWasDeleted(note: NSNotification) {
		if let convo = note.object as? Conversation, current = self.conversation where convo == current {
			self.conversation = Conversation.existingConversationWith(current.nonLocalSpeaker)
		}
	}
	
	func pendingStatusChanged(note: NSNotification) {
		self.updateUI()
		if self.messages.count > 0 {
			self.tableView?.scrollToRowAtIndexPath(NSIndexPath(forRow: self.messages.count - 1, inSection: 0), atScrollPosition: .Bottom, animated: true)
		}
	}
	
	func updateUI() {
		if ConversationKit.state == .NotSetup { return }
		
		self.loadTable()
		if ConversationKit.state == .Authenticated {
			self.openSettingsButton?.hidden = true
			self.notSignedInLabel?.hidden = true
			self.messages = self.conversation?.sortedMessages ?? []
			self.tableView?.reloadData()
		} else {
			if self.notSignedInLabel == nil {
				var frame = CGRectInset(self.bounds, 20, 20)
				frame.size.height -= 150
				self.notSignedInLabel = UILabel(frame: frame)
				self.addSubview(self.notSignedInLabel)
				self.notSignedInLabel.text = NSLocalizedString("Not signed in to iCloud.\n\n\nPlease enter your iCloud credentials into System Settings", comment: "Not signed into iCloud message")
				self.notSignedInLabel.numberOfLines = 0
				self.notSignedInLabel.textAlignment = .Center
				self.notSignedInLabel.lineBreakMode = .ByWordWrapping
				self.notSignedInLabel.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
				self.notSignedInLabel.textColor = UIColor.grayColor()
			}
			
			if self.openSettingsButton == nil {
				self.openSettingsButton = UIButton(type: .Custom)
				self.openSettingsButton.setTitle(NSLocalizedString("Open Settings", comment: "Open Settings"), forState: .Normal)
				self.openSettingsButton.sizeToFit()
				self.addSubview(self.openSettingsButton)
				self.openSettingsButton.setTitleColor(UIColor.blueColor(), forState: .Normal)
				self.openSettingsButton.center = CGPoint(x: self.bounds.midX, y: self.bounds.maxY - 50)
				self.openSettingsButton.addTarget(self, action: "openSettings", forControlEvents: .TouchUpInside)
				self.openSettingsButton.autoresizingMask = [.FlexibleTopMargin, .FlexibleLeftMargin, .FlexibleRightMargin]
			}
			self.tableView?.hidden = true
			self.notSignedInLabel?.hidden = false
			self.openSettingsButton?.hidden = false
		}
	}
	
	func openSettings() {
		UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
	}
	
	public var contentInset: UIEdgeInsets {
		get { return self.tableView?.contentInset ?? UIEdgeInsetsZero }
		set { self.tableView?.contentInset = newValue }
	}
	
	func newMessage(note: NSNotification) {
		self.updateUI()
		
		self.scrollToMessage(note.object as? Message)
	}
	
	func scrollToMessage(message: Message?) {
		if let message = message, index = self.messages.indexOf(message) {
			self.tableView?.scrollToRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0), atScrollPosition: .Bottom, animated: true)
		}
	}
	
	func scrollToLast() {
		self.updateUI()
		self.scrollToMessage(self.messages.last)
	}
}

extension ConversationView: UITableViewDataSource, UITableViewDelegate {
	func loadTable() {
		if self.tableView == nil {
			self.tableView = UITableView(frame: self.bounds, style: .Plain)
			self.addSubview(self.tableView)
			self.tableView.delegate = self
			self.tableView.dataSource = self
			self.tableView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight] 
			self.tableView.registerNib(UINib(nibName: "ConversationMessageTableViewCell", bundle: NSBundle(forClass: self.dynamicType)), forCellReuseIdentifier: ConversationMessageTableViewCell.identifier)
			self.tableView.separatorStyle = .None
		}
	}
	
	public func numberOfSectionsInTableView(tableView: UITableView) -> Int { return 1 }
	public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		guard let conversation = self.conversation else { return 0 }
		
		return self.messages.count + (conversation.hasPendingIncomingMessage ? 1 : 0)
	}
	
	func messageAtIndexPath(path: NSIndexPath) -> Message? {
		if path.row < self.messages.count { return self.messages[path.row] }
		return nil
	}
	
	public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier(ConversationMessageTableViewCell.identifier, forIndexPath: indexPath) as! ConversationMessageTableViewCell
		if let message = self.messageAtIndexPath(indexPath) {
			cell.message = message
			message.markAsRead()
		} else {
			cell.message = Message(speaker: self.conversation?.nonLocalSpeaker, content: "…")
		}
		return cell
	}
	
	public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		if let message = self.messageAtIndexPath(indexPath) {
			return ConversationMessageTableViewCell.heightForMessage(message, inTableWidth: tableView.bounds.width)
		}
		return 44.0
	}
	
	public func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String? {
		return self.allowMessageDeletion ? NSLocalizedString("Delete", comment: "Delete") : nil
	}
	
	public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if let message = self.messageAtIndexPath(indexPath) {
			tableView.beginUpdates()
			tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
			self.messages.removeAtIndex(indexPath.row)
			
			message.delete()
			tableView.endUpdates()
		}
	}
	
	public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return self.allowMessageDeletion
	}
}