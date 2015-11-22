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
	static var existingConversations: Set<Conversation> = []
	class func addExistingConversation(convo: Conversation) { dispatch_sync(ConversationKit.instance.queue) { self.existingConversations.insert(convo) } }
	
	public var startedBy: Speaker
	public var joinedBy: Speaker
	public var messages: Set<Message> = []
	
	public func addMessage(message: Message, fromCache: Bool) {
		dispatch_async(ConversationKit.instance.queue) { self.messages.insert(message) }
	}
	
	func hasSpeakers(speakers: [Speaker]) -> Bool {
		return speakers.contains(self.startedBy) && speakers.contains(self.joinedBy)
	}
	
	init(starter: Speaker, and other: Speaker) {
		startedBy = starter
		joinedBy = other
		super.init()
	}
	
	class func clearExistingConversations() {
		Conversation.existingConversations.removeAll()
	}
	
	class func conversationWithSpeaker(speaker: Speaker, listener: Speaker) -> Conversation {
		let speakers = [speaker, listener]
		
		for conversation in Conversation.existingConversations {
			if conversation.hasSpeakers(speakers) {
				return conversation
			}
		}
		
		let conversation = Conversation(starter: speaker, and: listener)
		self.addExistingConversation(conversation)
		conversation.loadMessagesFromCoreData()
		return conversation
	}
	
	func loadMessagesFromCoreData() {
		DataStore.instance.importBlock { moc in
			if let pred = self.messagePredicateInContext(moc) {
				let objects: [MessageObject] = moc.allObjects(pred, sortedBy: [NSSortDescriptor(key: "spokenAt", ascending: true)])
				
				for object in objects {
					let message = Message(object: object)
					self.addMessage(message, fromCache: true)
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
	
}