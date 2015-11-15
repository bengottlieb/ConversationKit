//
//  Conversation.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class Conversation: NSObject {
	
	
	var messages: [Message] {
		return []
	}
	
	var speakers: [Speaker] {
		return []
	}
	
	func messagesFromSpeaker(speaker: Speaker) -> [Message] {
		return []
	}
	
	func ingestNewMessage(message: Message) {
		
	}
}