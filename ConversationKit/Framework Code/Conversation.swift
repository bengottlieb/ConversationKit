//
//  Conversation.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

open class Conversation: NSObject {
	open var sortedMessages: [Message] { return Array(self.messages).sorted(by: <) }
	open var startedBy: Speaker
	open var joinedBy: Speaker
	open var nonLocalSpeaker: Speaker { return self.startedBy.isLocalSpeaker ? self.joinedBy : self.startedBy }
	open var hasPendingIncomingMessage = false {
		didSet {
			if self.hasPendingIncomingMessage != oldValue {
				Utilities.postNotification(ConversationKit.notifications.incomingPendingMessageChanged, object: self)
			}
		}
	}
	
	open var messagesLoaded = false
	open var isVisible: Bool = false {
		didSet {
			if self.isVisible {
				ConversationKit.addVisibleConversation(self)
			} else {
				ConversationKit.removeVisibleConversation(self)
			}
		}
	}
	
	var messages: Set<Message> = []
	static var existingConversations: Set<Conversation> = []
	class func addExistingConversation(_ convo: Conversation) {
		_ = ConversationKit.queue.sync { self.existingConversations.insert(convo) } }
	
	open class func existingConversationWith(_ speaker: Speaker?) -> Conversation? {
		guard let speaker = speaker else { return nil }
		
		let speakers = [speaker, Speaker.localSpeaker!]
		
		for conversation in Conversation.existingConversations {
			if conversation.hasSpeakers(speakers) {
				conversation.loadMessagesFromCoreData()
				return conversation
			}
		}
		
		return nil
	}
	
	open class func conversationBetween(_ speakers: [Speaker]) -> Conversation {
		let actual: [Speaker]
		
		if speakers.count == 1 && speakers[0] != Speaker.localSpeaker {
			actual = [speakers[0], Speaker.localSpeaker!]
		} else {
			actual = speakers
		}
		for conversation in Conversation.existingConversations {
			if conversation.hasSpeakers(actual) {
				return conversation
			}
		}
		
		let conversation = Conversation(starter: actual[0], and: actual[1])
		self.addExistingConversation(conversation)
		conversation.loadMessagesFromCoreData()
		return conversation
	}
	
	open var shortDescription: String {
		return "\(self.startedBy.name ?? "unnamed") <-> \(self.joinedBy.name ?? "unnamed")"
	}
	
	open func deleteConversation(_ completion: (() -> Void)? = nil) {
		_ = ConversationKit.queue.sync { Conversation.existingConversations.remove(self) }
		DataStore.instance.importBlock { moc in
			for message in self.messages {
				if let object = message.objectInContext(moc) { moc.delete(object) }
				message.deleteFromiCloud()
			}
			moc.safeSave(toDisk: false)
			Utilities.postNotification(ConversationKit.notifications.conversationDeleted, object: self)
			completion?()
		}
	}
	
	init(starter: Speaker, and other: Speaker) {
		startedBy = starter
		joinedBy = other
		super.init()
	}
	
	class func clearExistingConversations() {
		Conversation.existingConversations.removeAll()
	}
	
	func loadMessagesFromCoreData() {
		if self.messagesLoaded { return }
		self.messagesLoaded = true
		DataStore.instance.importBlock { moc in
			if let pred = self.messagePredicateInContext(moc) {
				let objects: [MessageObject] = moc.allObjects(pred, sortedBy: [NSSortDescriptor(key: "spokenAt", ascending: true)])
				
				for object in objects {
					let message = Message(object: object)
					self.addMessage(message, from: .coreDataCache)
				}
				ConversationKit.queue.async {
					Utilities.postNotification(ConversationKit.notifications.finishedLoadingMessagesForConversation, object: self)
				}
			}
		}
	}
	
	func messagePredicateInContext(_ moc: NSManagedObjectContext) -> NSPredicate? {
		if let speaker = self.startedBy.objectInContext(moc), let other = self.joinedBy.objectInContext(moc) {
			return NSPredicate(format: "(speaker == %@ || listener == %@) && (speaker == %@ || listener == %@)", speaker, speaker, other, other)
		}
		return nil
	}
	
	enum MessageCacheSource { case new, coreDataCache, iCloudCache }
	
	func addMessage(_ message: Message, from: MessageCacheSource) {
		message.conversation = self
		ConversationKit.queue.async {
			self.messages.insert(message)
			
			switch from {
			case .iCloudCache: Utilities.postNotification(ConversationKit.notifications.downloadedOldMessage, object: message)
			case .coreDataCache: break
			case .new: Utilities.postNotification(ConversationKit.notifications.postedNewMessage, object: message)
			}
		}
	}
	
	func removeMessage(_ message: Message) {
		ConversationKit.queue.async {
			self.messages.remove(message)
		}
	}
	
	func hasSpeakers(_ speakers: [Speaker]) -> Bool {
		return speakers.contains(self.startedBy) && speakers.contains(self.joinedBy)
	}
	
}
