//
//  ConversationMessagesTableView.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/23/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

public class ConversationView: UIView {
	public var conversation: Conversation? { didSet { self.scrollToLast() } }
	public var allowMessageDeletion = true
	
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
	}
	
	var tableView: UITableView!
	var messages: [Message] = []
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		self.loadTable()
	}
	
	func updateUI() {
		self.messages = self.conversation?.sortedMessages ?? []
		self.tableView?.reloadData()
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
			self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0), atScrollPosition: .Bottom, animated: true)
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
		return self.messages.count
	}
	
	func messageAtIndexPath(path: NSIndexPath) -> Message? {
		if path.row < self.messages.count { return self.messages[path.row] }
		return nil
	}
	
	public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier(ConversationMessageTableViewCell.identifier, forIndexPath: indexPath) as! ConversationMessageTableViewCell
		cell.message = self.messageAtIndexPath(indexPath)
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