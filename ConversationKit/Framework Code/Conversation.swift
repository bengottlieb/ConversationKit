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

public class Conversation: CloudManagedObject {
	@NSManaged var startedBy: Speaker?
	@NSManaged var joinedBy: Speaker?
	
	
	class func conversationBetween(starter: Speaker, and other: Speaker, completion: ((Bool) -> Void)?) -> Conversation {
		let moc = starter.moc!
		
		if let existing: Conversation = moc.anyObject(NSPredicate(format: "(startedBy == %@ || startedBy == %@) && (joinedBy == %@ || joinedBy == %@)", starter, other, starter, other)) {
			return existing
		}
		
		let convo: Conversation = moc.insertObject()
		convo.startedBy = starter
		convo.joinedBy = other
		convo.saveToCloudKit(completion)
		
		return convo
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
	
	
	override func loadFromCloudKitRecord(record: CKRecord) {
	}
	
	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		if let starterID = self.startedBy?.cloudKitRecordID, joinedID = self.joinedBy?.cloudKitRecordID {
			let starterRef = CKReference(recordID: starterID, action: .DeleteSelf)
			let joinedByRef = CKReference(recordID: joinedID, action: .DeleteSelf)
			
			record["startedBy"] = starterRef
			record["joinedBy"] = joinedByRef
			return true
		}
		return false
	}


}