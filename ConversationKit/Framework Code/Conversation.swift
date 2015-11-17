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
	
	func addMessage(message: Message) {
		dispatch_async(ConversationKit.instance.queue) { self.messages.insert(message) }
	}
	
	func hasMembers(members: [Speaker]) -> Bool {
		return members.contains(self.startedBy) && members.contains(self.joinedBy)
	}
	
	init(starter: Speaker, and other: Speaker) {
		startedBy = starter
		joinedBy = other
		super.init()
	}
	
	class func conversationWithSpeaker(speaker: Speaker, listener: Speaker) -> Conversation {
		let members = [speaker, listener]
		
		for conversation in Conversation.existingConversations {
			if conversation.hasMembers(members) {
				return conversation
			}
		}
		
		let conversation = Conversation(starter: speaker, and: listener)
		self.addExistingConversation(conversation)
		return conversation
	}
	
}