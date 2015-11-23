//
//  ConversationMessagesTableView.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/23/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

public class ConversationView: UIView {
	public var conversation: Conversation? { didSet {
		self.updateUI()
		}
	}
	
	public override init(frame: CGRect) {
		super.init(frame: frame)
		self.setup()
	}
	
	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.setup()
	}
	
	func setup() {
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateUI", name: ConversationKit.notifications.finishedLoadingMessagesForConversation, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateUI", name: ConversationKit.notifications.postedNewMessage, object: nil)
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
		}
	}
	
	public func numberOfSectionsInTableView(tableView: UITableView) -> Int { return 1 }
	public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.messages.count
	}
	
	public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier(ConversationMessageTableViewCell.identifier, forIndexPath: indexPath) as! ConversationMessageTableViewCell
		cell.message = self.messages[indexPath.row]
		return cell
	}
}