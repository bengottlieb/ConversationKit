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
	
	convenience init(tag: String, includeLocal: Bool = false, completion: (Speaker?) -> Void) {
		self.init(nibName: nil, bundle: nil)
		
		self.completion = completion
		self.query = SpeakerQuery(tag: tag)
		self.includeLocalSpeaker = includeLocal
		self.reloadTable()
		
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "cancel")
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "reloadTable", name: ConversationKit.notifications.foundNewSpeaker, object: nil)
		self.query.start { speakers in
			self.refreshControl?.endRefreshing()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
		
		self.refreshControl?.beginRefreshing()
	}
	
	func reloadTable() {
		var speakers = Speaker.allKnownSpeakers()
		
		if !self.includeLocalSpeaker, let localSpeaker = Speaker.localSpeaker, index = speakers.indexOf(localSpeaker) {
			speakers.removeAtIndex(index)
		}
		self.speakers = speakers.sort { $0.name < $1.name }
		self.tableView.reloadData()
	}
	
	func cancel() {
		self.dismissViewControllerAnimated(true, completion: nil)
		self.completion?(nil)
	}
	
	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.speakers.count
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath)
		
		cell.textLabel?.text = self.speakers[indexPath.row].name
		cell.imageView?.image = self.speakers[indexPath.row].avatarImage
		return cell
	}
	
	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let speaker = self.speakers[indexPath.row]
		self.completion?(speaker)
		self.dismissViewControllerAnimated(true, completion: nil)
	}
}
