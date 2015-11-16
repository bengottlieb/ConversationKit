//
//  Conversation.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class Conversation: NSObject {
	init(speakers spkrs: [Speaker]) {
		speakers = spkrs
		super.init()
	}
	
	public var messages: [Message] = []
	public let speakers: [Speaker]
	
	public func messagesFromSpeaker(speaker: Speaker) -> [Message] {
		return []
	}
	
	public func createNewMessage(content: String, speaker: Speaker = Speaker.localSpeaker) {
		let message = Message(conversation: self, content: content, speaker: speaker)
		self.messages.append(message)
	}
}

extension Conversation {
	
	func ingestNewMessage(message: Message) {
		
	}

}