//
//  ConversationMessagesTableView.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/23/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

open class ConversationView: UIView {
	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	open var conversation: Conversation? { didSet {
		self.loadTable()
		self.scrollToLast()
	}}
	open var allowMessageDeletion = true
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
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationView.scrollToLast), name: ConversationKit.notifications.finishedLoadingMessagesForConversation, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationView.newMessage(_:)), name: ConversationKit.notifications.postedNewMessage, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationView.updateUI), name: ConversationKit.notifications.downloadedOldMessage, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationView.updateUI), name: ConversationKit.notifications.iCloudAccountIDChanged, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationView.pendingStatusChanged(_:)), name: ConversationKit.notifications.incomingPendingMessageChanged, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationView.conversationWasDeleted(_:)), name: ConversationKit.notifications.conversationDeleted, object: nil)
		
		self.updateUI()
	}
	
	open override func layoutSubviews() {
		super.layoutSubviews()
		self.loadTable()
	}
	
	func conversationWasDeleted(_ note: Notification) {
		if let convo = note.object as? Conversation, let current = self.conversation , convo == current {
			self.conversation = Conversation.existing(with: current.nonLocalSpeaker)
		}
	}
	
	func pendingStatusChanged(_ note: Notification) {
		self.updateUI()
		if self.messages.count > 0 {
			self.tableView?.scrollToRow(at: IndexPath(row: self.messages.count, section: 0), at: .bottom, animated: true)
		}
	}
	
	func updateUI() {
		if ConversationKit.state == .notSetup { return }
		
		self.loadTable()
		if ConversationKit.isAuthenticated {
			self.openSettingsButton?.isHidden = true
			self.notSignedInLabel?.isHidden = true
			self.messages = self.conversation?.sortedMessages ?? []
			self.tableView?.reloadData()
		} else {
			if self.notSignedInLabel == nil {
				var frame = self.bounds.insetBy(dx: 20, dy: 20)
				frame.size.height -= 150
				self.notSignedInLabel = UILabel(frame: frame)
				self.addSubview(self.notSignedInLabel)
				self.notSignedInLabel.text = NSLocalizedString("Not signed in to iCloud.\n\n\nPlease enter your iCloud credentials into System Settings", comment: "Not signed into iCloud message")
				self.notSignedInLabel.numberOfLines = 0
				self.notSignedInLabel.textAlignment = .center
				self.notSignedInLabel.lineBreakMode = .byWordWrapping
				self.notSignedInLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
				self.notSignedInLabel.textColor = UIColor.gray
			}
			
			if self.openSettingsButton == nil {
				self.openSettingsButton = UIButton(type: .custom)
				self.openSettingsButton.setTitle(NSLocalizedString("Open Settings", comment: "Open Settings"), for: UIControlState())
				self.openSettingsButton.sizeToFit()
				self.addSubview(self.openSettingsButton)
				self.openSettingsButton.setTitleColor(UIColor.blue, for: UIControlState())
				self.openSettingsButton.center = CGPoint(x: self.bounds.midX, y: self.bounds.maxY - 50)
				self.openSettingsButton.addTarget(self, action: #selector(ConversationView.openSettings), for: .touchUpInside)
				self.openSettingsButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
			}
			self.tableView?.isHidden = true
			self.notSignedInLabel?.isHidden = false
			self.openSettingsButton?.isHidden = false
		}
	}
	
	func openSettings() {
		UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
	}
	
	open var contentInset: UIEdgeInsets {
		get { return self.tableView?.contentInset ?? UIEdgeInsets.zero }
		set { self.tableView?.contentInset = newValue }
	}
	
	func newMessage(_ note: Notification) {
		self.updateUI()
		
		self.scrollToMessage(note.object as? Message)
	}
	
	func scrollToMessage(_ message: Message?) {
		if let message = message, let index = self.messages.index(of: message) {
			self.tableView?.scrollToRow(at: IndexPath(row: index, section: 0), at: .bottom, animated: true)
		}
	}
	
	func scrollToLast() {
		self.updateUI()
		self.scrollToMessage(self.messages.last)
	}

	let emptyCell = UITableViewCell(style: .default, reuseIdentifier: "empty")
}

extension ConversationView: UITableViewDataSource, UITableViewDelegate {
	func loadTable() {
		if self.tableView == nil {
			self.tableView = UITableView(frame: self.bounds, style: .plain)
			self.addSubview(self.tableView)
			self.tableView.delegate = self
			self.tableView.dataSource = self
			self.tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight] 
			self.tableView.register(UINib(nibName: "ConversationMessageTableViewCell", bundle: Bundle(for: type(of: self))), forCellReuseIdentifier: ConversationMessageTableViewCell.identifier)
		}
		self.tableView.separatorColor = UIColor.clear
		self.tableView.separatorStyle = .none
	}
	
	public func numberOfSections(in tableView: UITableView) -> Int { return 1 }
	public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//		guard let conversation = self.conversation else { return 0 }
		
		return self.messages.count + 1
	}
	
	func messageAtIndexPath(_ path: IndexPath) -> Message? {
		if path.row < self.messages.count { return self.messages[path.row] }
		return nil
	}
	
	public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: ConversationMessageTableViewCell.identifier, for: indexPath) as! ConversationMessageTableViewCell
		if let message = self.messageAtIndexPath(indexPath) {
			cell.message = message
			message.markAsRead()
		} else {
			if self.conversation?.hasPendingIncomingMessage == true {
				cell.message = Message(speaker: self.conversation?.nonLocalSpeaker, content: "…")
			} else {
				return self.emptyCell
			}
		}
		return cell
	}
	
	public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if let message = self.messageAtIndexPath(indexPath) {
			return ConversationMessageTableViewCell.heightForMessage(message, inTableWidth: tableView.bounds.width)
		}
		
		if self.conversation?.hasPendingIncomingMessage == true { return 44.0 }
		return 0
	}
	
	public func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
		return self.allowMessageDeletion ? NSLocalizedString("Delete", comment: "Delete") : nil
	}
	
	public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if let message = self.messageAtIndexPath(indexPath) {
			tableView.beginUpdates()
			tableView.deleteRows(at: [indexPath], with: .automatic)
			self.messages.remove(at: indexPath.row)
			
			message.delete()
			tableView.endUpdates()
		}
	}
	
	public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return self.allowMessageDeletion
	}
}
