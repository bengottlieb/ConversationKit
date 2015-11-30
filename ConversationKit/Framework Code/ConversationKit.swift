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
	@objc public enum FeedbackLevel: Int { case Development = 0, Testing = 1, Production = 2 }
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
	public var setupComplete = false
	
	public struct notifications {
		public static let setupComplete = "ConversationKit.setupComplete"
		public static let updateComplete = "ConversationKit.updateComplete"
		public static let localSpeakerUpdated = "ConversationKit.localSpeakerUpdated"
		public static let loadedKnownSpeakers = "ConversationKit.loadedKnownSpeakers"
		public static let foundNewSpeaker = "ConversationKit.foundNewSpeaker"
		public static let postedNewMessage = "ConversationKit.postedNewMessage"
		public static let downloadedOldMessage = "ConversationKit.downloadedOldMessage"
		public static let finishedLoadingMessagesForConversation = "ConversationKit.finishedLoadingMessagesForConversation"
		public static let finishedLoadingMessagesOldMessages = "ConversationKit.finishedLoadingMessagesOldMessages"
		public static let iCloudAccountIDChanged = "ConversationKit.iCloudAccountIDChanged"
	}
	
	override init() {
		super.init()
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
	}
	
	func applicationDidBecomeActive() {
		Cloud.instance.pullDownMessages()
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
			if let recordID = ckNotification.recordID {
				Cloud.instance.handleNotificationCloudRecordID(recordID) { success in
					completionHandler(.NewData)
				}
				return
			}
		}

		completionHandler(.NewData)
	}
	
	public class func fetchAccountIdentifier(completion: (String?) -> Void) {
		Cloud.instance.fetchAccountIdentifier(completion)
	}
	
	public class func setup(containerName: String? = nil, feedbackLevel: FeedbackLevel = ConversationKit.feedbackLevel, completion: ((Bool) -> Void)? = nil) {
		ConversationKit.feedbackLevel = feedbackLevel
		if ConversationKit.feedbackLevel != .Production { self.log("Setting up ConversationKit, feedback level: \(ConversationKit.feedbackLevel.rawValue)") }
		
		if !self.instance.setupComplete {
			self.instance.reloadFromICloud(containerName, completion: completion)
		}
	}
	
	func reloadFromICloud(containerName: String? = nil, completion: ((Bool) -> Void)? = nil) {
		self.setupComplete = false
		Speaker.loadCachedSpeakers {
			Cloud.instance.setup(containerName) { configured in
				self.setupComplete = true
				completion?(configured)
			}
		}
	}
	
	public class func setupLocalSpeaker(speakerIdentifier: String, completion: (Bool) -> Void) {
		if !self.instance.setupComplete {
			self.setup() { success in if (success) { self.setupLocalSpeaker(speakerIdentifier, completion: completion) } }
			return
		}
		guard let speaker = Speaker.localSpeaker else {
			ConversationKit.instance.loadLocalSpeaker(speakerIdentifier, completion: completion)
			return
		}
		
		if speaker.identifier == speakerIdentifier {
			completion(true)
			return
		}
		
		self.clearAllCachedDataWithCompletion {
			ConversationKit.instance.loadLocalSpeaker(speakerIdentifier, completion: completion)
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
			Speaker.localSpeaker?.refreshFromCloud() { success in
				Speaker.localSpeaker.identifier = identifier
				Speaker.localSpeaker.refreshFromCloud { complete in
					Speaker.localSpeaker.saveToCloudKit { success in
						Cloud.instance.setupSubscription()
						Cloud.instance.pullDownMessages(false)
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
		do {
			try NSFileManager.defaultManager().removeItemAtURL(DataStore.instance.imagesCacheURL)
			try NSFileManager.defaultManager().createDirectoryAtURL(DataStore.instance.imagesCacheURL, withIntermediateDirectories: true, attributes: nil)
		} catch {}
		DataStore.instance.clearAllCachedDataWithCompletion {
			Speaker.loadCachedSpeakers {
				completion()
			}
		}
	}
	
	internal let queue = dispatch_queue_create("ConversationKitQueue", DISPATCH_QUEUE_SERIAL)
}

extension ConversationKit {
	class func log(message: String, error: ErrorType? = nil) {
		if ConversationKit.feedbackLevel != .Production {
			print("••• \(message)" + (error != nil ? ": \(error)" : ""))
		}
	}
}