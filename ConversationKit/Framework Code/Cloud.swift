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

open class Cloud: NSObject {
	static let lastPendingFetchedAtKey = "lastFetchedAt"

	static let instance = Cloud()
	
	var containerID: String?
	open var container: CKContainer!
	open var database: CKDatabase!
	
	open func setup(_ completion: @escaping () -> Void) {
		self.queue.async {
			if ConversationKit.state != .notSetup {
				completion()
				return
			}
			self.container = (self.containerID == nil) ? CKContainer.default() : CKContainer(identifier: self.containerID!)
			self.database = self.container.publicCloudDatabase
			
			NotificationCenter.default.addObserver(self, selector: #selector(Cloud.updateICloudAccountStatus), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)

			self.container.accountStatus { status, error in
				if let err = error {
					ConversationKit.log("Error while configuring CloudKit", error: err)
				} else {
					switch status {
					case .available:
						ConversationKit.state = .authenticated
						self.fetchAccountIdentifier { identifier in
							Speaker.loadCachedSpeakers { completion() }
						}

					case .couldNotDetermine:
						ConversationKit.state = .notSetup

					case .noAccount:
						ConversationKit.state = .authenticatedNoAccount
						Speaker.loadCachedSpeakers { completion() }

					case .restricted:
						ConversationKit.state = .notSetup
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
	
	func fetchAccountIdentifier(_ completion: @escaping (String?) -> Void) {
		Cloud.instance.setup { configured in
			if let ident = self.currentICloudAccountID {
				completion(ident)
				return
			}
			guard ConversationKit.state != .notSetup else { completion(nil); return }
			self.queue.async {
				self.pendingAccountIDClosures.append(completion)
				
				if !self.fetchingAccountIdentifer {
					self.fetchingAccountIdentifer = true

					Cloud.instance.container.fetchUserRecordID { recordID, error in
						if (error != nil) { ConversationKit.log("Problem fetching account info record ID", error: error) }
						self.queue.async {
							let original = self.previousICloudAccountID
							let closures = self.pendingAccountIDClosures
							self.pendingAccountIDClosures = []
							self.currentICloudAccountID = recordID == nil ? nil : "ID:\(recordID!.recordName)"
							ConversationKit.state = self.currentICloudAccountID == nil ? .authenticatedNoAccount : .authenticated
			
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
	
	func pullDownMessages(_ all: Bool = false) {
		guard ConversationKit.state != .notSetup, let localUserID = Speaker.localSpeaker?.identifier else { return }
		
		if self.queryOperation == nil {
			ConversationKit.instance.networkActivityUsageCount += 1
			var pred = NSPredicate(format: "speakers contains %@", localUserID)
			
			if !all, let date = DataStore.instance[Cloud.lastPendingFetchedAtKey] as? Date {
				pred = NSCompoundPredicate(andPredicateWithSubpredicates: [pred, NSPredicate(format: "spokenAt > %@", date as CVarArg)])
				ConversationKit.log("pulling down messages for \(localUserID) starting at \(date)")
			} else {
				ConversationKit.log("pulling all messages down for \(localUserID)")
			}
			
			DataStore.instance[Cloud.lastPendingFetchedAtKey] = Date() as AnyObject?
			let query = CKQuery(recordType: Message.recordName, predicate: pred)
			self.queryOperation = CKQueryOperation(query: query)
			self.parsingContext = DataStore.instance.createWorkerContext()
			
			self.queryOperation!.recordFetchedBlock = { record in
				guard let moc = self.parsingContext else { return }
				moc.perform {
					if !Message.recordExists(record, inContext: moc), let message = Message(record: record) {
						message.saveManagedObject(inContext: moc)
						ConversationKit.log("\(message.content)")
						Conversation.conversationBetween([message.listener, message.speaker]).addMessage(message, from: .iCloudCache)
					}
				}
			}
			
			self.queryOperation!.queryCompletionBlock = { cursor, error in
				let moc = self.parsingContext
				moc?.perform {
					ConversationKit.log("message loading complete")
					moc?.safeSave(toDisk: true)
					self.queryOperation = nil
					self.parsingContext = nil
					Utilities.postNotification(ConversationKit.notifications.finishedLoadingMessagesOldMessages)
					Utilities.postNotification(ConversationKit.notifications.setupComplete)
					ConversationKit.instance.networkActivityUsageCount -= 1
				}
			}
			
			self.database.add(self.queryOperation!)
		}
	}
	
	let messagesSubscriptionID = "messageSubscriptionID"
	var messagesSubscription: CKSubscription?

	let pendingSubscriptionID = "pendingbscriptionID"
	var pendingSubscription: CKSubscription?

	open func discontinueSubscription(_ identifier: String?) {
		for sub in [self.messagesSubscription] {
			guard let sub = sub else { continue }
			self.database.delete(withSubscriptionID: sub.subscriptionID, completionHandler: { subID, error in
				if error != nil { ConversationKit.log("Error deleting subscription", error: error) }
			})
		}
	}
	
	func setupSubscription() {
		guard ConversationKit.state != .notSetup, let localUserID = Speaker.localSpeaker.identifier else { return }
		
		if self.messagesSubscription == nil {
			let pred = NSPredicate(format: "speakers contains %@", localUserID)
			self.messagesSubscription = CKSubscription(recordType: Message.recordName, predicate: pred, subscriptionID: self.messagesSubscriptionID, options: .firesOnRecordCreation)
			let info = CKNotificationInfo()
			info.shouldSendContentAvailable = true
//			info.alertBody = "Test Alert"
//			info.alertLocalizationKey = "%1$@ : %2$@"
//			info.alertLocalizationArgs = ["speakerName", "content"]
			
			self.messagesSubscription?.notificationInfo = info
			self.database.save(self.messagesSubscription!, completionHandler: { sub, error in
				ConversationKit.log("Finished Creating Message Subscription: \(sub)", error: error)
			})
		}

		if self.pendingSubscription == nil {
			let pred = NSPredicate(format: "recipient = %@", localUserID)
			self.pendingSubscription = CKSubscription(recordType: PendingMessage.recordName, predicate: pred, subscriptionID: self.pendingSubscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate])
			let info = CKNotificationInfo()
			info.shouldSendContentAvailable = true
			
			self.pendingSubscription?.notificationInfo = info
			self.database.save(self.pendingSubscription!, completionHandler: { sub, error in
				ConversationKit.log("Finished Creating Pending Subscription: \(sub)", error: error)
			})
		}
	}
	
	
	
	internal func handleNotificationCloudRecordID(_ recordID: CKRecordID, reason: CKQueryNotificationReason, completion: @escaping (Bool) -> Void) {
		self.database.fetch(withRecordID: recordID) { incoming, error in
			if let record = incoming {
				if record.recordType == Message.recordName {
					
					DataStore.instance.importBlock { moc in
						if !Message.recordExists(record, inContext: moc), let message = Message(record: record) {
							message.saveManagedObject(inContext: moc)
							ConversationKit.log("\(message.content)")
							let convo = Conversation.conversationBetween([message.listener, message.speaker])
							convo.addMessage(message, from: .new)
							ConversationKit.displayIncomingMessage(message)
						}
						completion(true)
					}
					return
				} else if record.recordType == PendingMessage.recordName {
					if let speaker = Speaker.speaker(fromID: record["speaker"] as? String), let conversation = Conversation.existingConversationWith(speaker) {
						conversation.hasPendingIncomingMessage = record["lastPendingAt"] != nil
					}
				}
			}
			completion(false)
		}
	}
	
	internal let queue = DispatchQueue(label: "ConversationKitCloudQueue", attributes: [])
}
