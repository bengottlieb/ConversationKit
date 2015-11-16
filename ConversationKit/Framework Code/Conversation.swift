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
	class func conversationWithSpeakers(speakers: [Speaker]) -> Conversation {
		let moc = speakers[0].moc!
		
		if let existing: Conversation = moc.anyObject(NSPredicate(format: "(speakers.@count == %d) AND (SUBQUERY(speakers, $x, $x IN %@).@count == %d)", speakers.count, speakers, speakers.count)) {
			return existing
		}
		
		let convo: Conversation = moc.insertObject()
		speakers.forEach { convo.addSpeaker($0) }
		return convo
	}
	
//	public func messagesFromSpeaker(speaker: Speaker) -> [Message] {
//		return self.messages.flatMap { return $0.speaker == speaker ? $0 : nil }
//	}
	
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