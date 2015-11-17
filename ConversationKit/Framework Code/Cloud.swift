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
	
	public func setup(containerID: String? = nil, completion: (() -> Void)?) {
		dispatch_async(self.queue) {
			if self.setupComplete {
				completion?()
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
				completion?()
			}
		}
	}
	
	
	internal func reportError(error: NSError?, note: String) {
		guard let error = error else { return }
		
		print("\(note): \(error)")
	}
	
	internal let queue = dispatch_queue_create("ConversationKitQueue", DISPATCH_QUEUE_SERIAL)
	internal var container: CKContainer!
	internal var database: CKDatabase!
}
