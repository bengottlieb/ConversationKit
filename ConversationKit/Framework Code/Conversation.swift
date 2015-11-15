//
//  Conversation.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class Conversation: NSObject {
	
	
	public var messages: [Message] {
		return []
	}
	
	public var speakers: [Speaker] {
		return []
	}
	
	public func messagesFromSpeaker(speaker: Speaker) -> [Message] {
		return []
	}
	
	public func createNewMessage(content: String, speaker: Speaker  = Speaker.localSpeaker) {
		
	}
}

extension Conversation {
	
	func ingestNewMessage(message: Message) {
		
	}

}