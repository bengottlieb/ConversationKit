//
//  SelectSpeaker.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/20/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit
import ConversationKit

class SelectSpeakerViewController: UITableViewController {
	var includeLocalSpeaker = false
	var speakers: [Speaker] = []
	var query: SpeakerQuery!
	var completion: ((Speaker?) -> Void)?
	
	convenience init(tag: String, includeLocal: Bool = false, completion: @escaping (Speaker?) -> Void) {
		self.init(nibName: nil, bundle: nil)
		
		self.completion = completion
		self.query = SpeakerQuery(tag: tag)
		self.includeLocalSpeaker = includeLocal
		self.reloadTable()
		
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(SelectSpeakerViewController.cancel))
		
		NotificationCenter.default.addObserver(self, selector: #selector(SelectSpeakerViewController.messagesLoaded), name: ConversationKit.notifications.finishedLoadingMessagesForConversation, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(SelectSpeakerViewController.reloadTable), name: ConversationKit.notifications.foundNewSpeaker, object: nil)
		self.query.start { speakers in
			self.refreshControl?.endRefreshing()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
		
		self.refreshControl?.beginRefreshing()
	}
	
	func messagesLoaded(_ note: Notification) {
		if let convo = note.object as? Conversation, let index = self.speakers.index(of: convo.nonLocalSpeaker) {
			let path = IndexPath(item: index, section: 0)
			self.tableView.beginUpdates()
			self.tableView.reloadRows(at: [path], with: .automatic)
			self.tableView.endUpdates()
		}
	}
	
	func reloadTable() {
		var speakers = Speaker.allKnownSpeakers()
		
		if !self.includeLocalSpeaker, let localSpeaker = Speaker.localSpeaker, let index = speakers.index(of: localSpeaker) {
			speakers.remove(at: index)
		}
		self.speakers = speakers.sorted {
			($0.name ?? "") < ($1.name ?? "")
		}
		self.tableView.reloadData()
	}
	
	func cancel() {
		self.dismiss(animated: true, completion: nil)
		self.completion?(nil)
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.speakers.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
		let speaker = self.speakers[indexPath.row]
		
		cell.textLabel?.text = speaker.name
		cell.imageView?.image = speaker.avatarImage ?? MessageBubbleView.defaultImagePlaceholder
		
		if let messageCount = Conversation.existingConversationWith(speaker)?.sortedMessages.count , messageCount > 0 {
			let label = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
			label.text = "\(messageCount)"
			label.textColor = UIColor.lightGray
			label.sizeToFit()
			cell.accessoryView = label
		} else {
			cell.accessoryView = nil
		}
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let speaker = self.speakers[indexPath.row]
		self.completion?(speaker)
		self.dismiss(animated: true, completion: nil)
	}
	
	override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
		return "Delete Conversation"
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		let speaker = self.speakers[indexPath.row]
		if let convo = Conversation.existingConversationWith(speaker) {
			convo.deleteConversation() {
				Utilities.mainThread { tableView.reloadData() }
			}
		}
	}
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		let speaker = self.speakers[indexPath.row]
		return Conversation.existingConversationWith(speaker)?.sortedMessages.isEmpty == false
	}

}
