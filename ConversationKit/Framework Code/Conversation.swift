//
//  Conversation.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CoreData

public class Conversation: NSManagedObject {
	public var messages: [Message] = []
	public let speakers: [Speaker] = []
	
	class func conversationWithSpeakers(speakers: [Speaker], inContext moc: NSManagedObjectContext) -> Conversation {
		let convo: Conversation = moc.insertObject()
		speakers.forEach { convo.addSpeaker($0) }
		return convo
	}
	
	public func messagesFromSpeaker(speaker: Speaker) -> [Message] {
		return self.messages.flatMap { return $0.speaker == speaker ? $0 : nil }
	}
	
	public func createNewMessage(content: String, speaker: Speaker? = nil) {
		let message: Message = self.moc!.insertObject()
		message.speaker = speaker ?? self.moc!.localSpeaker
		message.content = content
		message.conversation = self
	}
	
	func addSpeaker(speaker: Speaker) {
		let set = self.mutableSetValueForKey("speakers")
		set.addObject(speaker)
	}
}

extension Conversation {
	
	func ingestNewMessage(message: Message) {
		
	}

}