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
	
	func pullDownMessages() {
		if !self.configured { return }
		
		let ref = Speaker.localSpeaker.cloudKitReference
		let pred = NSPredicate(format: "speakers contains %@", ref)
		let query = CKQuery(recordType: Message.recordName, predicate: pred)
		let operation = CKQueryOperation(query: query)
		
		operation.recordFetchedBlock = { record in
			Router.instance.importMessage(record)
		}
		
		operation.queryCompletionBlock = { cursor, error in
			Utilities.postNotification(ConversationKit.notifications.setupComplete)
		}
		
		self.database.addOperation(operation)
	}
	
	internal func reportError(error: NSError?, note: String) {
		guard let error = error else { return }
		
		print("\(note): \(error)")
	}
	
	internal let queue = dispatch_queue_create("ConversationKitCloudQueue", DISPATCH_QUEUE_SERIAL)
}
