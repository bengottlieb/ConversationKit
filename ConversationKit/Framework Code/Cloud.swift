//
//  Cloud.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CloudKit

public class Cloud: NSObject {
	public static let instance = Cloud()
	
	public var configured = false
	public var setupComplete = false
	public var container: CKContainer!
	public var database: CKDatabase!
	
	public func setup(containerID: String? = nil, completion: (Bool) -> Void) {
		dispatch_async(self.queue) {
			if self.setupComplete {
				completion(self.configured)
				return
			}
			self.container = (containerID == nil) ? CKContainer.defaultContainer() : CKContainer(identifier: containerID!)
			self.database = self.container.publicCloudDatabase
			
			self.container.accountStatusWithCompletionHandler { status, error in
				if let err = error {
					print("Error while configuring CloudKit: \(err)")
				} else if status != .Available {
					print("no access to CloudKit account: \(status)")
				} else {
					print("CloudKit access secured")
					self.configured = true
				}
				
				self.setupComplete = true
				completion(self.configured)
			}
		}
	}
	
	var queryOperation: CKQueryOperation?
	func pullDownMessages() {
		guard self.configured, let localUserID = Speaker.localSpeaker.identifier else { return }
		
		if self.queryOperation == nil {
			print("pulling down messages for \(localUserID)")
			let pred = NSPredicate(format: "speakers contains %@", localUserID)
			let query = CKQuery(recordType: Message.recordName, predicate: pred)
			self.queryOperation = CKQueryOperation(query: query)
			
			self.queryOperation!.recordFetchedBlock = { record in
				if let message = Message(record: record) {
					message.saveManagedObject()
					Conversation.conversationWithSpeaker(message.speaker, listener: message.listener).addMessage(message)
				}
			}
			
			self.queryOperation!.queryCompletionBlock = { cursor, error in
				Utilities.postNotification(ConversationKit.notifications.setupComplete)
				print("message loading complete")
				self.queryOperation = nil
			}
			
			self.database.addOperation(self.queryOperation!)
		}
	}
	
	internal func reportError(error: NSError?, note: String) {
		guard let error = error else { return }
		
		print("\(note): \(error)")
	}
	
	internal let queue = dispatch_queue_create("ConversationKitCloudQueue", DISPATCH_QUEUE_SERIAL)
}
