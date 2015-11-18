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
	
	public func addMessage(message: Message) {
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
	
	class func conversationWithSpeaker(speaker: Speaker, listener: Speaker) -> Conversation {
		let speakers = [speaker, listener]
		
		for conversation in Conversation.existingConversations {
			if conversation.hasSpeakers(speakers) {
				return conversation
			}
		}
		
		let conversation = Conversation(starter: speaker, and: listener)
		self.addExistingConversation(conversation)
		return conversation
	}
	
}