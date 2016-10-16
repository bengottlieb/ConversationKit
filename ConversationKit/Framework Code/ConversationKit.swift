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

open class ConversationKit: NSObject {
	@objc public enum State: Int { case notSetup, authenticatedNoAccount, authenticated }
	@objc public enum FeedbackLevel: Int { case verbose = 0, development = 1, testing = 2, production = 3 }
	open static var feedbackLevel = FeedbackLevel.development
	open static var state = State.notSetup
	
	open var showNetworkActivityIndicatorBlock: (Bool) -> Void = { enable in
		UIApplication.shared.isNetworkActivityIndicatorVisible = enable
	}
	
	internal var networkActivityUsageCount = 0 { didSet {
		if self.networkActivityUsageCount == 0 && oldValue != 0 {
			Utilities.mainThread { self.showNetworkActivityIndicatorBlock(false) }
		} else if self.networkActivityUsageCount != 0 && oldValue == 0 {
			Utilities.mainThread { self.showNetworkActivityIndicatorBlock(true) }
		}
	}}

	open static var cloudAvailable: Bool { return ConversationKit.state != .notSetup }

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
		NotificationCenter.default.addObserver(self, selector: #selector(ConversationKit.applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
	}
	
	func applicationDidBecomeActive() {
		Cloud.instance.pullDownMessages()
	}
	
	static let MessageReplyAction = "MessageReplyAction"
	static let MessageCategory = "MessageCategory"

	open class func configureNotifications(_ application: UIApplication) {
		let categories: Set<UIMutableUserNotificationCategory>
		
		if UIApplication.shared.delegate!.responds(to: #selector(UIApplicationDelegate.application(_:handleActionWithIdentifier:for:withResponseInfo:completionHandler:))) {
			let replyAction = UIMutableUserNotificationAction()
			replyAction.identifier = self.MessageReplyAction
			replyAction.behavior = .textInput
			replyAction.activationMode = .background
			replyAction.isDestructive = false
			replyAction.isAuthenticationRequired = false
			replyAction.title = NSLocalizedString("Reply", comment: "Reply to message option")

			let category = UIMutableUserNotificationCategory()
			category.identifier = self.MessageCategory
			category.setActions([replyAction], for: .default)
			category.setActions([replyAction], for: .minimal)
			
			categories = [category]
		} else {
			categories = []
		}
		
		let settings = UIUserNotificationSettings(types: [.alert, .sound], categories: categories)

		application.registerUserNotificationSettings(settings)
		application.registerForRemoteNotifications()
	}
	
	open class func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject]) as? CKQueryNotification , ckNotification.notificationType == .query {
			print("received notification: \(ckNotification)")
			if let recordID = ckNotification.recordID {
				Cloud.instance.handleNotificationCloudRecordID(recordID, reason: ckNotification.queryNotificationReason) { success in
					completionHandler(.newData)
				}
				return
			}
		}

		completionHandler(.newData)
	}
	
	open class func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, withResponseInfo responseInfo: [AnyHashable: Any], completionHandler: @escaping () -> Void) {
		
		Cloud.instance.setup {
			if let text = responseInfo[UIUserNotificationActionResponseTypedTextKey] as? String, let speakerRef = notification.userInfo?["speaker"] as? String, let speaker = Speaker.speaker(fromRef: speakerRef) {
				speaker.send(message: text) { success in
					completionHandler()
				}
				return
			}
			
			completionHandler()
		}
	}

	
	open class func fetchAccountIdentifier(_ completion: @escaping (String?) -> Void) {
		Cloud.instance.fetchAccountIdentifier(completion)
	}
	
	open class func setup(_ feedbackLevel: FeedbackLevel = ConversationKit.feedbackLevel, completion: (() -> Void)? = nil) {
		ConversationKit.feedbackLevel = feedbackLevel
		if ConversationKit.feedbackLevel != .production { self.log("Setting up ConversationKit, feedback level: \(ConversationKit.feedbackLevel.rawValue)") }
		
		if ConversationKit.state == .notSetup {
			Cloud.instance.setup() {
				completion?()
			}
		} else {
			completion?()
		}
	}
	
	open class func setupLocalSpeaker(_ speakerIdentifier: String, completion: @escaping () -> Void) {
		ConversationKit.log("Setting up local speaker, identifier \(speakerIdentifier)")
		if ConversationKit.state == .notSetup {
			self.setup() { if (ConversationKit.state != .notSetup) {
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

	func loadLocalSpeaker(_ identifier: String, completion: (() -> Void)?) {
		ConversationKit.log("Loading local speaker ID: \(identifier)")
		let defaults = UserDefaults.standard
		if let prevLoggedInAs = defaults.string(forKey: self.lastSignedInAsKey) , prevLoggedInAs != identifier {
			ConversationKit.log("New Local Speaker ID found (was \(prevLoggedInAs)), resetting store.")
			defaults.set(identifier, forKey: self.lastSignedInAsKey)
			defaults.synchronize()
			ConversationKit.clearAllCachedDataWithCompletion {
				self.loadLocalSpeaker(identifier, completion: completion)
			}
			return
		}
		
		defaults.set(identifier, forKey: self.lastSignedInAsKey)
		defaults.synchronize()

		if ConversationKit.state != .notSetup {
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
	
	open class func clearAllCachedDataWithCompletion(_ completion: @escaping () -> Void) {
		Conversation.clearExistingConversations()
		Speaker.clearKnownSpeakers {
			do {
				try FileManager.default.removeItem(at: DataStore.instance.imagesCacheURL as URL)
				try FileManager.default.createDirectory(at: DataStore.instance.imagesCacheURL as URL, withIntermediateDirectories: true, attributes: nil)
			} catch {}
			DataStore.instance.clearAllCachedDataWithCompletion {
				Speaker.loadCachedSpeakers {
					completion()
				}
			}
		}
	}
	
	internal static let queue = DispatchQueue(label: "ConversationKitQueue", attributes: [])
	internal static var pendingMessageDisplays: [Message] = []
	
	static var visibleConversations: Set<Conversation> = []
	open static var messageDisplayWindow: UIWindow?
	var currentDisplayedMessage: MessageReceivedDropDown?


}

extension ConversationKit {
	internal class func log(_ message: String, error: Error? = nil, onlyIfError: Bool = true) {
		if onlyIfError && error == nil { return }
		
		if ConversationKit.feedbackLevel != .verbose, let error = error as? NSError, error.shouldBeSupressed { return }
		if error == nil && ConversationKit.feedbackLevel == .production { return }
		
		print("••• \(message)" + (error != nil ? ": \(error)" : ""))
	}
}

extension NSError {
	var shouldBeSupressed: Bool {
		if self.domain == CKErrorDomain {
			return self.code == 11
		}
		return false
	}
}
