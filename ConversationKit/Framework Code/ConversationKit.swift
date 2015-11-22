//
//  ConversationKit.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/14/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

public class ConversationKit: NSObject {
	public var showNetworkActivityIndicatorBlock: (Bool) -> Void = { enable in
		UIApplication.sharedApplication().networkActivityIndicatorVisible = enable
	}
	internal var networkActivityUsageCount = 0 { didSet {
		if self.networkActivityUsageCount == 0 && oldValue != 0 {
			Utilities.mainThread { self.showNetworkActivityIndicatorBlock(false) }
		} else if self.networkActivityUsageCount != 0 && oldValue == 0 {
			Utilities.mainThread { self.showNetworkActivityIndicatorBlock(true) }
		}
	}}
	
	public static let instance = ConversationKit()
	public var setupComplete = false
	
	public struct notifications {
		public static let setupComplete = "ConversationKit.setupComplete"
		public static let updateComplete = "ConversationKit.updateComplete"
		public static let localSpeakerUpdated = "ConversationKit.localSpeakerUpdated"
		public static let loadedKnownSpeakers = "ConversationKit.loadedKnownSpeakers"
		public static let foundNewSpeaker = "ConversationKit.foundNewSpeaker"
	}
	
	public func setupNotificationSettings(application: UIApplication) {
		#if (arch(i386) || arch(x86_64)) && os(iOS)
			ConversationKit.log("Push Notifications disabled in the simulator")
		#else
			application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Alert, categories: nil))
			application.registerForRemoteNotifications()
		#endif
	}
	
	public func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject]) as? CKQueryNotification where ckNotification.notificationType == .Query {
			let recordID = ckNotification.recordID
			
			ConversationKit.log("Received note: \(recordID)")
		}

		completionHandler(.NewData)
	}
	
	public func fetchAccountIdentifier(completion: (String?) -> Void) {
		Cloud.instance.setup { configured in
			guard configured else { completion(nil); return }

			Cloud.instance.container.fetchUserRecordIDWithCompletionHandler { recordID, error in
				Cloud.instance.reportError(error, note: "Problem fetching account info record ID")
				guard let recordID = recordID else { completion(nil); return }
				
				completion("ID:\(recordID.recordName)")
			}
		}
	}
	
	public func setup(containerName: String? = nil, localSpeakerIdentifier: String, completion: ((Bool) -> Void)? = nil) {
		Speaker.loadCachedSpeakers {
			Cloud.instance.setup(containerName) { configured in
				self.loadLocalSpeaker(localSpeakerIdentifier, completion: completion)
			}
		}
	}

	let lastSignedInAsKey = "lastSignedInAs"

	public func loadLocalSpeaker(identifier: String, completion: ((Bool) -> Void)?) {
		let defaults = NSUserDefaults.standardUserDefaults()
		if let prevLoggedInAs = defaults.stringForKey(self.lastSignedInAsKey) where prevLoggedInAs != identifier {
			defaults.setObject(identifier, forKey: self.lastSignedInAsKey)
			defaults.synchronize()
			self.clearAllCachedDataWithCompletion {
				self.loadLocalSpeaker(identifier, completion: completion)
			}
			return
		}
		
		if Cloud.instance.configured {
			Speaker.localSpeaker.refreshFromCloud() { success in
				Speaker.localSpeaker.identifier = identifier
				Speaker.localSpeaker.refreshFromCloud { complete in
					Speaker.localSpeaker.saveToCloudKit { success in
						if !self.setupComplete {
							self.setupComplete = true
							Utilities.postNotification(ConversationKit.notifications.setupComplete)
						}
						Cloud.instance.setupSubscription()
						Cloud.instance.pullDownMessages(true)
						completion?(success)
					}
				}
			}
		} else {
			completion?(false)
		}
	}
	
	public func clearAllCachedDataWithCompletion(completion: () -> Void) {
		Conversation.clearExistingConversations()
		Speaker.clearKnownSpeakers()
		DataStore.instance.clearAllCachedDataWithCompletion(completion)
	}
	
	internal let queue = dispatch_queue_create("ConversationKitQueue", DISPATCH_QUEUE_SERIAL)
}

extension ConversationKit {
	class func log(message: String) {
		print("••• \(message)")
	}
}