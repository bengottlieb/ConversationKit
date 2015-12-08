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
	@objc public enum State: Int { case NotSetup, AuthenticatedNoAccount, Authenticated }
	@objc public enum FeedbackLevel: Int { case Development = 0, Testing = 1, Production = 2 }
	public static var feedbackLevel = FeedbackLevel.Development
	public static var state = State.NotSetup
	
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

	public static var cloudAvailable: Bool { return ConversationKit.state != .NotSetup }

	static let instance = ConversationKit()
	
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
		public static let incomingPendingMessageChanged = "ConversationKit.incomingPendingMessageChanged"
		public static let conversationDeleted = "ConversationKit.conversationDeleted"
		public static let conversationSelected = "ConversationKit.conversationSelected"
	}
	
	override init() {
		super.init()
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
	}
	
	func applicationDidBecomeActive() {
		Cloud.instance.pullDownMessages()
	}
	
	static let MessageReplyAction = "MessageReplyAction"
	static let MessageCategory = "MessageCategory"

	public class func configureNotifications(application: UIApplication) {
		let categories: Set<UIMutableUserNotificationCategory>
		
		if UIApplication.sharedApplication().delegate!.respondsToSelector("application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:") {
			let replyAction = UIMutableUserNotificationAction()
			replyAction.identifier = self.MessageReplyAction
			replyAction.behavior = .TextInput
			replyAction.activationMode = .Background
			replyAction.destructive = false
			replyAction.authenticationRequired = false
			replyAction.title = NSLocalizedString("Reply", comment: "Reply to message option")

			let category = UIMutableUserNotificationCategory()
			category.identifier = self.MessageCategory
			category.setActions([replyAction], forContext: .Default)
			category.setActions([replyAction], forContext: .Minimal)
			
			categories = [category]
		} else {
			categories = []
		}
		
		let settings = UIUserNotificationSettings(forTypes: [.Alert, .Sound], categories: categories)

		application.registerUserNotificationSettings(settings)
		application.registerForRemoteNotifications()
	}
	
	public class func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject]) as? CKQueryNotification where ckNotification.notificationType == .Query {
			print("received notification: \(ckNotification)")
			if let recordID = ckNotification.recordID {
				Cloud.instance.handleNotificationCloudRecordID(recordID, reason: ckNotification.queryNotificationReason) { success in
					completionHandler(.NewData)
				}
				return
			}
		}

		completionHandler(.NewData)
	}
	
	public class func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, withResponseInfo responseInfo: [NSObject : AnyObject], completionHandler: () -> Void) {
		
		Cloud.instance.setup {
			if let text = responseInfo[UIUserNotificationActionResponseTypedTextKey] as? String, speakerRef = notification.userInfo?["speaker"] as? String, speaker = Speaker.speakerFromIdentifier(speakerRef) {
				speaker.sendMessage(text) { success in
					completionHandler()
				}
				return
			}
			
			completionHandler()
		}
	}

	
	public class func fetchAccountIdentifier(completion: (String?) -> Void) {
		Cloud.instance.fetchAccountIdentifier(completion)
	}
	
	public class func setup(feedbackLevel: FeedbackLevel = ConversationKit.feedbackLevel, completion: (() -> Void)? = nil) {
		ConversationKit.feedbackLevel = feedbackLevel
		if ConversationKit.feedbackLevel != .Production { self.log("Setting up ConversationKit, feedback level: \(ConversationKit.feedbackLevel.rawValue)") }
		
		if ConversationKit.state == .NotSetup {
			Cloud.instance.setup() {
			}
		}
	}
	
	public class func setupLocalSpeaker(speakerIdentifier: String, completion: () -> Void) {
		if ConversationKit.state == .NotSetup {
			self.setup() { if (ConversationKit.state != .NotSetup) {
				self.setupLocalSpeaker(speakerIdentifier, completion: completion)
			}}
			return
		}
		guard let speaker = Speaker.localSpeaker else {
			ConversationKit.instance.loadLocalSpeaker(speakerIdentifier, completion: completion)
			return
		}
		
		if speaker.identifier == speakerIdentifier {
			ConversationKit.instance.loadLocalSpeaker(speakerIdentifier, completion: completion)
			return
		}
		
		if speaker.identifier == nil {
			ConversationKit.instance.loadLocalSpeaker(speakerIdentifier, completion: completion)
		} else {
			self.clearAllCachedDataWithCompletion {
				ConversationKit.instance.loadLocalSpeaker(speakerIdentifier, completion: completion)
			}
		}
	}

	let lastSignedInAsKey = "lastSignedInAs"

	func loadLocalSpeaker(identifier: String, completion: (() -> Void)?) {
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

		if ConversationKit.state != .NotSetup {
			Speaker.localSpeaker?.refreshFromCloud() { success in
				Speaker.localSpeaker.identifier = identifier
				Speaker.localSpeaker.refreshFromCloud { complete in
					Speaker.localSpeaker.saveToCloudKit { success in
						Cloud.instance.setupSubscription()
						Cloud.instance.pullDownMessages(false)
						completion?()
					}
				}
			}
		} else {
			completion?()
		}
	}
	
	public class func clearAllCachedDataWithCompletion(completion: () -> Void) {
		Conversation.clearExistingConversations()
		Speaker.clearKnownSpeakers {
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
	}
	
	internal static let queue = dispatch_queue_create("ConversationKitQueue", DISPATCH_QUEUE_SERIAL)
	internal static var pendingMessageDisplays: [Message] = []
	
	static var visibleConversations: Set<Conversation> = []
	public static var messageDisplayWindow: UIWindow?
	var currentDisplayedMessage: MessageReceivedDropDown?


}

extension ConversationKit {
	class func log(message: String, error: ErrorType? = nil) {
		if ConversationKit.feedbackLevel != .Production {
			print("••• \(message)" + (error != nil ? ": \(error)" : ""))
		}
	}
}