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

public class Conversation: NSObject {
	public var sortedMessages: [Message] { return Array(self.messages ?? []).sort(<) }
	public var startedBy: Speaker
	public var joinedBy: Speaker
	public var nonLocalSpeaker: Speaker { return self.startedBy.isLocalSpeaker ? self.joinedBy : self.startedBy }
	public var hasPendingIncomingMessage = false {
		didSet {
			if self.hasPendingIncomingMessage != oldValue {
				Utilities.postNotification(ConversationKit.notifications.incomingPendingMessageChanged, object: self)
			}
		}
	}
	
	public var isVisible: Bool = false {
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
	class func addExistingConversation(convo: Conversation) { dispatch_sync(ConversationKit.queue) { self.existingConversations.insert(convo) } }
	
	public class func existingConversationWith(speaker: Speaker?) -> Conversation? {
		guard let speaker = speaker else { return nil }
		
		let speakers = [speaker, Speaker.localSpeaker!]
		
		for conversation in Conversation.existingConversations {
			if conversation.hasSpeakers(speakers) {
				return conversation
			}
		}
		
		return nil
	}
	
	public class func conversationBetween(speakers: [Speaker]) -> Conversation {
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
	
	public var shortDescription: String {
		return "\(self.startedBy.name ?? "unnamed") <-> \(self.joinedBy.name ?? "unnamed")"
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
		DataStore.instance.importBlock { moc in
			if let pred = self.messagePredicateInContext(moc) {
				let objects: [MessageObject] = moc.allObjects(pred, sortedBy: [NSSortDescriptor(key: "spokenAt", ascending: true)])
				
				for object in objects {
					let message = Message(object: object)
					self.addMessage(message, from: .CoreDataCache)
				}
				dispatch_async(ConversationKit.queue) {
					Utilities.postNotification(ConversationKit.notifications.finishedLoadingMessagesForConversation, object: self)
				}
			}
		}
	}
	
	func messagePredicateInContext(moc: NSManagedObjectContext) -> NSPredicate? {
		if let speaker = self.startedBy.objectInContext(moc), other = self.joinedBy.objectInContext(moc) {
			return NSPredicate(format: "(speaker == %@ || listener == %@) && (speaker == %@ || listener == %@)", speaker, speaker, other, other)
		}
		return nil
	}
	
	enum MessageCacheSource { case New, CoreDataCache, iCloudCache }
	
	func addMessage(message: Message, from: MessageCacheSource) {
		message.conversation = self
		dispatch_async(ConversationKit.queue) {
			self.messages.insert(message)
			
			switch from {
			case .iCloudCache: Utilities.postNotification(ConversationKit.notifications.downloadedOldMessage, object: message)
			case .CoreDataCache: break
			case .New: Utilities.postNotification(ConversationKit.notifications.postedNewMessage, object: message)
			}
		}
	}
	
	func removeMessage(message: Message) {
		dispatch_async(ConversationKit.queue) {
			self.messages.remove(message)
		}
	}
	
	func hasSpeakers(speakers: [Speaker]) -> Bool {
		return speakers.contains(self.startedBy) && speakers.contains(self.joinedBy)
	}
	
}