//
//  Message.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public class Message: CloudManagedObject {
	@NSManaged public var conversation: Conversation?
	@NSManaged public var content: String?
	@NSManaged public var speaker: Speaker?

	override func loadFromCloudKitRecord(record: CKRecord) {
		self.content = record["content"] as? String
	}
	
	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		if let speakerID = self.speaker?.cloudKitRecordID, convoID = self.conversation?.cloudKitRecordID {
			let speakerRef = CKReference(recordID: speakerID, action: .DeleteSelf)
			let convoRef = CKReference(recordID: convoID, action: .DeleteSelf)
			
			record["content"] = self.content
			record["speaker"] = speakerRef
			record["conversation"] = convoRef
			return true
		}
		return false
	}
}