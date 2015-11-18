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
	public var content = ""
	public var speaker: Speaker!
	public var listener: Speaker!
	public var spokenAt = NSDate()
	
	convenience init(speaker: Speaker, listener: Speaker, content: String) {
		self.init()
		
		self.speaker = speaker
		self.listener = listener
		self.content = content
		self.spokenAt = NSDate()
		self.needsCloudSave = true
		self.cloudKitRecordID = CKRecordID(recordName: "Message: \(NSUUID().UUIDString)")
	}
	
	convenience init?(record: CKRecord) {
		self.init()
		
		
		guard let speakers = record["speakers"] as? [String] where speakers.count == 2 else { return nil }
		
		self.readFromCloudKitRecord(record)
	}
	
	override func readFromCloudKitRecord(record: CKRecord) {
		self.content = record["content"] as? String ?? ""
		self.spokenAt = record["spokenAt"] as? NSDate ?? NSDate()
		self.cloudKitRecordID = record.recordID
		
		if let speakers = record["speakers"] as? [String] where speakers.count == 2 {
			let speaker = Speaker.speakerWithIdentifier(speakers[0]), listener = Speaker.speakerWithIdentifier(speakers[1])

			self.speaker = speaker
			self.listener = listener
		}
	}
	
	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		if let speakerID = self.speaker?.identifier, listenerID = self.listener?.identifier {
			
			record["spokenAt"] = self.spokenAt;
			record["content"] = self.content
			record["speakers"] = [speakerID, listenerID]
			return true
		}
		return self.needsCloudSave
	}
	
	override func writeToManagedObject(object: ManagedCloudObject) {
		guard let messageObject = object as? MessageRecord else { return }
		
		messageObject.content = self.content
		messageObject.speaker = self.speaker?.objectInContext(object.moc!) as? SpeakerRecord
		messageObject.listener = self.listener?.objectInContext(object.moc!) as? SpeakerRecord
		messageObject.spokenAt = self.spokenAt
	}
	
	internal override class var recordName: String { return "Message" }
	internal override class var entityName: String { return "MessageRecord" }

	internal override var canSaveToCloud: Bool {
		return self.speaker != nil && self.listener != nil
	}
}

internal class MessageRecord: ManagedCloudObject {
	@NSManaged var content: String?
	@NSManaged var speaker: SpeakerRecord?
	@NSManaged var listener: SpeakerRecord?
	@NSManaged var spokenAt: NSDate?
}