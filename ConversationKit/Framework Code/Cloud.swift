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
	
	public struct notifications {
		static let configurationComplete = "ConversationKit.cloud.configurationComplete"
	}
	
	public var configured = false
	public func setup(containerID: String? = nil) {
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
			
			Utilities.postNotification(Cloud.notifications.configurationComplete)
		}
	}
	
	private var container: CKContainer!
	private var database: CKDatabase!
}
