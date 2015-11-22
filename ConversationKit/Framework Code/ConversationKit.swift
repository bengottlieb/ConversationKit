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
	public enum FeedbackLevel: String { case Development, Testing, Production }
	public static var feedbackLevel = FeedbackLevel.Development
	
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

	public static var cloudAvailable: Bool { return Cloud.instance.configured }

	static let instance = ConversationKit()
	var setupComplete = false
	
	public struct notifications {
		public static let setupComplete = "ConversationKit.setupComplete"
		public static let updateComplete = "ConversationKit.updateComplete"
		public static let localSpeakerUpdated = "ConversationKit.localSpeakerUpdated"
		public static let loadedKnownSpeakers = "ConversationKit.loadedKnownSpeakers"
		public static let foundNewSpeaker = "ConversationKit.foundNewSpeaker"
		public static let postedNewMessage = "ConversationKit.postedNewMessage"
		public static let finishedLoadingMessagesForConversation = "ConversationKit.finishedLoadingMessagesForConversation"
	}
	
	public class func configureNotifications(application: UIApplication) {
		#if (arch(i386) || arch(x86_64)) && os(iOS)
			ConversationKit.log("Push Notifications disabled in the simulator")
		#else
			application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Alert, categories: nil))
			application.registerForRemoteNotifications()
		#endif
	}
	
	public class func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject]) as? CKQueryNotification where ckNotification.notificationType == .Query {
			let recordID = ckNotification.recordID
			
			ConversationKit.log("Received note: \(recordID)")
		}

		completionHandler(.NewData)
	}
	
	public class func fetchAccountIdentifier(completion: (String?) -> Void) {
		Cloud.instance.setup { configured in
			guard configured && Cloud.instance.iCloudAccountIDAvailable else { completion(nil); return }

			Cloud.instance.container.fetchUserRecordIDWithCompletionHandler { recordID, error in
				Cloud.instance.reportError(error, note: "Problem fetching account info record ID")
				guard let recordID = recordID else { completion(nil); return }
				
				completion("ID:\(recordID.recordName)")
			}
		}
	}
	
	public class func setup(containerName: String? = nil, localSpeakerIdentifier: String, completion: ((Bool) -> Void)? = nil) {
		if ConversationKit.feedbackLevel != .Production { self.log("Setting up ConversationKit, feedback level: \(ConversationKit.feedbackLevel.rawValue)") }
		
		Speaker.loadCachedSpeakers {
			Cloud.instance.setup(containerName) { configured in
				ConversationKit.instance.loadLocalSpeaker(localSpeakerIdentifier, completion: completion)
			}
		}
	}
	
	public class func changeLocalSpeaker(newSpeakerIdentifier: String, completion: (Bool) -> Void) {
		guard let speaker = Speaker.localSpeaker else {
			self.setup(localSpeakerIdentifier: newSpeakerIdentifier, completion: completion)
			return
		}
		
		if speaker.identifier == newSpeakerIdentifier {
			completion(true)
			return
		}
		
		self.clearAllCachedDataWithCompletion {
			self.setup(localSpeakerIdentifier: newSpeakerIdentifier, completion: completion)
		}
	}

	let lastSignedInAsKey = "lastSignedInAs"

	func loadLocalSpeaker(identifier: String, completion: ((Bool) -> Void)?) {
		ConversationKit.log("Loading local speaker ID: \(identifier)")
		let defaults = NSUserDefaults.standardUserDefaults()
		if let prevLoggedInAs = defaults.stringForKey(self.lastSignedInAsKey) where prevLoggedInAs != identifier {
			ConversationKit.log("New Local Speaker ID found (was \(prevLoggedInAs)), resetting store.")
			defaults.setObject(identifier, forKey: self.lastSignedInAsKey)
			defaults.synchronize()
			ConversationKit.clearAllCachedDataWithCompletion {
				self.loadLocalSpeaker(identifier, completion: completion)
			}
			return
		}
		
		defaults.setObject(identifier, forKey: self.lastSignedInAsKey)
		defaults.synchronize()

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
	
	public class func clearAllCachedDataWithCompletion(completion: () -> Void) {
		Conversation.clearExistingConversations()
		Speaker.clearKnownSpeakers()
		DataStore.instance.clearAllCachedDataWithCompletion {
			Speaker.loadCachedSpeakers {
				completion()
			}
		}
	}
	
	internal let queue = dispatch_queue_create("ConversationKitQueue", DISPATCH_QUEUE_SERIAL)
}

extension ConversationKit {
	class func log(message: String) {
		if ConversationKit.feedbackLevel != .Production {
			print("••• \(message)")
		}
	}
}