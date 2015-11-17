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

public class Message: CloudObject {
	var content = ""
	var speaker: Speaker!
	var listener: Speaker!
	var spokenAt = NSDate()
	
	override func loadFromCloudKitRecord(record: CKRecord) {
		self.content = record["content"] as? String ?? ""
		self.spokenAt = record["spokenAt"] as? NSDate ?? NSDate()
	}

	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		if let speakerID = self.speaker?.cloudKitRecordID, listenerID = self.listener?.cloudKitRecordID {
			let speakerRef = CKReference(recordID: speakerID, action: .DeleteSelf)
			let listenerRef = CKReference(recordID: listenerID, action: .DeleteSelf)
			
			record["spokenAt"] = self.spokenAt;
			record["content"] = self.content
			record["speaker"] = speakerRef
			record["listener"] = listenerRef
			return true
		}
		return false
	}

}

internal class MessageRecord: ManagedCloudObject {
	@NSManaged var content: String?
	@NSManaged var speaker: Speaker?
	
}