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
	
	override func readFromCloudKitRecord(record: CKRecord) {
		self.content = record["content"] as? String ?? ""
		self.spokenAt = record["spokenAt"] as? NSDate ?? NSDate()
		
		if let ref = record["speaker"] as? CKReference {
			self.speaker = Speaker.loadSpeakerFromRecordID(ref.recordID) { speaker in
				self.speaker = speaker
				self.saveManagedObject(nil)
			}
			self.saveManagedObject(nil)
		}
	}
	
	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		if let speakerID = self.speaker?.cloudKitRecordID, listenerID = self.listener?.cloudKitRecordID {
			let speakerRef = CKReference(recordID: speakerID, action: .DeleteSelf)
			let listenerRef = CKReference(recordID: listenerID, action: .DeleteSelf)
			
			record["spokenAt"] = self.spokenAt;
			record["content"] = self.content
			record["speakers"] = [speakerRef, listenerRef]
			return true
		}
		return false
	}
	
	override func writeToManagedObject(object: ManagedCloudObject) {
		guard let messageObject = object as? MessageRecord else { return }
		
		messageObject.content = self.content
		messageObject.speaker = self.speaker?.objectInContext(object.moc!) as? SpeakerRecord
		messageObject.listener = self.speaker?.objectInContext(object.moc!) as? SpeakerRecord
		messageObject.spokenAt = self.spokenAt
	}
	
	internal override class var recordName: String { return "Speaker" }
	internal override class var entityName: String { return "SpeakerRecord" }

}

internal class MessageRecord: ManagedCloudObject {
	@NSManaged var content: String?
	@NSManaged var speaker: SpeakerRecord?
	@NSManaged var listener: SpeakerRecord?
	@NSManaged var spokenAt: NSDate?
}