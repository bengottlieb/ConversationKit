//
//  Cloud.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CloudKit
import CoreData
import UIKit

public class Cloud: NSObject {
	static let lastPendingFetchedAtKey = "lastFetchedAt"

	static let instance = Cloud()
	
	var containerID: String?
	public var container: CKContainer!
	public var database: CKDatabase!
	
	public func setup(completion: () -> Void) {
		dispatch_async(self.queue) {
			if ConversationKit.state != .NotSetup {
				completion()
				return
			}
			self.container = (self.containerID == nil) ? CKContainer.defaultContainer() : CKContainer(identifier: self.containerID!)
			self.database = self.container.publicCloudDatabase
			
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateICloudAccountStatus", name: UIApplicationWillEnterForegroundNotification, object: nil)

			self.container.accountStatusWithCompletionHandler { status, error in
				if let err = error {
					ConversationKit.log("Error while configuring CloudKit", error: err)
				} else {
					switch status {
					case .Available:
						ConversationKit.state = .Authenticated
						self.fetchAccountIdentifier { identifier in
							Speaker.loadCachedSpeakers { completion() }
						}

					case .CouldNotDetermine:
						ConversationKit.state = .NotSetup

					case .NoAccount:
						ConversationKit.state = .AuthenticatedNoAccount
						Speaker.loadCachedSpeakers { completion() }

					case .Restricted:
						ConversationKit.state = .NotSetup
						ConversationKit.log("Restricted: no access to CloudKit account")
						completion()
					}
				}
				
			}
		}
	}
	
	var currentICloudAccountID: String?
	var previousICloudAccountID: String?
	var fetchingAccountIdentifer = false
	var pendingAccountIDClosures: [(String?) -> Void] = []
	
	func updateICloudAccountStatus() {
		self.previousICloudAccountID = self.currentICloudAccountID
		self.currentICloudAccountID = nil
		self.fetchAccountIdentifier { identifier in }
	}
	
	func fetchAccountIdentifier(completion: (String?) -> Void) {
		Cloud.instance.setup { configured in
			if let ident = self.currentICloudAccountID {
				completion(ident)
				return
			}
			guard ConversationKit.state != .NotSetup else { completion(nil); return }
			dispatch_async(self.queue) {
				self.pendingAccountIDClosures.append(completion)
				
				if !self.fetchingAccountIdentifer {
					self.fetchingAccountIdentifer = true

					Cloud.instance.container.fetchUserRecordIDWithCompletionHandler { recordID, error in
						if (error != nil) { ConversationKit.log("Problem fetching account info record ID", error: error) }
						dispatch_async(self.queue) {
							let original = self.previousICloudAccountID
							let closures = self.pendingAccountIDClosures
							self.pendingAccountIDClosures = []
							self.currentICloudAccountID = recordID == nil ? nil : "ID:\(recordID!.recordName)"
							ConversationKit.state = self.currentICloudAccountID == nil ? .AuthenticatedNoAccount : .Authenticated
			
							for completion in closures {
								completion(self.currentICloudAccountID)
							}
							
							self.fetchingAccountIdentifer = false
							self.previousICloudAccountID = nil
							if original != self.currentICloudAccountID {
								Speaker.loadCachedSpeakers {
									Utilities.postNotification(ConversationKit.notifications.iCloudAccountIDChanged)
								}
							}
						}
					}
				}
			}
		}
	}
	
	var queryOperation: CKQueryOperation?
	
	var parsingContext: NSManagedObjectContext!
	
	func pullDownMessages(all: Bool = false) {
		guard ConversationKit.state != .NotSetup, let localUserID = Speaker.localSpeaker?.identifier else { return }
		
		if self.queryOperation == nil {
			ConversationKit.instance.networkActivityUsageCount++
			var pred = NSPredicate(format: "speakers contains %@", localUserID)
			
			if !all, let date = DataStore.instance[Cloud.lastPendingFetchedAtKey] as? NSDate {
				pred = NSCompoundPredicate(andPredicateWithSubpredicates: [pred, NSPredicate(format: "spokenAt > %@", date)])
				ConversationKit.log("pulling down messages for \(localUserID) starting at \(date)")
			} else {
				ConversationKit.log("pulling all messages down for \(localUserID)")
			}
			
			DataStore.instance[Cloud.lastPendingFetchedAtKey] = NSDate()
			let query = CKQuery(recordType: Message.recordName, predicate: pred)
			self.queryOperation = CKQueryOperation(query: query)
			self.parsingContext = DataStore.instance.createWorkerContext()
			
			self.queryOperation!.recordFetchedBlock = { record in
				let moc = self.parsingContext
				moc.performBlock {
					if !Message.recordExists(record, inContext: moc), let message = Message(record: record) {
						message.saveManagedObject(inContext: moc)
						ConversationKit.log("\(message.content)")
						Conversation.conversationBetween([message.listener, message.speaker]).addMessage(message, from: .iCloudCache)
					}
				}
			}
			
			self.queryOperation!.queryCompletionBlock = { cursor, error in
				let moc = self.parsingContext
				moc.performBlock {
					ConversationKit.log("message loading complete")
					moc.safeSave()
					self.queryOperation = nil
					self.parsingContext = nil
					Utilities.postNotification(ConversationKit.notifications.finishedLoadingMessagesOldMessages)
					Utilities.postNotification(ConversationKit.notifications.setupComplete)
					ConversationKit.instance.networkActivityUsageCount--
				}
			}
			
			self.database.addOperation(self.queryOperation!)
		}
	}
	
	let messagesSubscriptionID = "messageSubscriptionID"
	var messagesSubscription: CKSubscription?

	let pendingSubscriptionID = "pendingbscriptionID"
	var pendingSubscription: CKSubscription?

	public func discontinueSubscription(identifier: String?) {
		for sub in [self.messagesSubscription] {
			guard let sub = sub else { continue }
			self.database.deleteSubscriptionWithID(sub.subscriptionID, completionHandler: { subID, error in
				if error != nil { ConversationKit.log("Error deleting subscription", error: error) }
			})
		}
	}
	
	func setupSubscription() {
		guard ConversationKit.state != .NotSetup, let localUserID = Speaker.localSpeaker.identifier else { return }
		
		if self.messagesSubscription == nil {
			let pred = NSPredicate(format: "speakers contains %@", localUserID)
			self.messagesSubscription = CKSubscription(recordType: Message.recordName, predicate: pred, subscriptionID: self.messagesSubscriptionID, options: .FiresOnRecordCreation)
			let info = CKNotificationInfo()
			info.shouldSendContentAvailable = true
//			info.alertBody = "Test Alert"
//			info.alertLocalizationKey = "%1$@ : %2$@"
//			info.alertLocalizationArgs = ["speakerName", "content"]
			
			self.messagesSubscription?.notificationInfo = info
			self.database.saveSubscription(self.messagesSubscription!, completionHandler: { sub, error in
				ConversationKit.log("Finished Creating Message Subscription: \(sub)", error: error)
			})
		}

		if self.pendingSubscription == nil {
			let pred = NSPredicate(format: "recipient = %@", localUserID)
			self.pendingSubscription = CKSubscription(recordType: PendingMessage.recordName, predicate: pred, subscriptionID: self.pendingSubscriptionID, options: [.FiresOnRecordCreation, .FiresOnRecordUpdate])
			let info = CKNotificationInfo()
			info.shouldSendContentAvailable = true
			
			self.pendingSubscription?.notificationInfo = info
			self.database.saveSubscription(self.pendingSubscription!, completionHandler: { sub, error in
				ConversationKit.log("Finished Creating Pending Subscription: \(sub)", error: error)
			})
		}
	}
	
	
	
	internal func handleNotificationCloudRecordID(recordID: CKRecordID, reason: CKQueryNotificationReason, completion: (Bool) -> Void) {
		self.database.fetchRecordWithID(recordID) { incoming, error in
			if let record = incoming {
				if record.recordType == Message.recordName {
					
					DataStore.instance.importBlock { moc in
						if !Message.recordExists(record, inContext: moc), let message = Message(record: record) {
							message.saveManagedObject(inContext: moc)
							ConversationKit.log("\(message.content)")
							let convo = Conversation.conversationBetween([message.listener, message.speaker])
							convo.addMessage(message, from: .New)
							ConversationKit.displayIncomingMessage(message)
						}
						completion(true)
					}
					return
				} else if record.recordType == PendingMessage.recordName {
					if let speaker = Speaker.speakerFromIdentifier(record["speaker"] as? String), conversation = Conversation.existingConversationWith(speaker) {
						conversation.hasPendingIncomingMessage = record["lastPendingAt"] != nil
					}
				}
			}
			completion(false)
		}
	}
	
	internal let queue = dispatch_queue_create("ConversationKitCloudQueue", DISPATCH_QUEUE_SERIAL)
}
