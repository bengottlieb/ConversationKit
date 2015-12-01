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
	public var conversation: Conversation?
	public var readAt: NSDate?
	
	class func recordExists(record: CKRecord, inContext moc: NSManagedObjectContext) -> Bool {
		let pred = NSPredicate(format: "cloudKitRecordIDName == %@", record.recordID.recordName)
		let object: MessageObject? = moc.anyObject(pred)
		
		return object != nil
	}

	convenience init?(speaker: Speaker?, content: String) {
		self.init()
		
		if speaker == nil { return nil }
		
		self.speaker = speaker
		self.content = content
	}
	
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
	
	convenience init(object: MessageObject) {
		self.init()
		
		self.readFromManagedObject(object)
	}
	
	static var hasRemindedAboutPermissions = false
	public func markAsRead() {
		if self.readAt == nil && !(self.speaker?.isLocalSpeaker ?? true) {
			self.readAt = NSDate()
			self.needsCloudSave = true
			self.save() { error in
				if let err = error where err.code == 10 && !Message.hasRemindedAboutPermissions && ConversationKit.feedbackLevel != .Production {
					Message.hasRemindedAboutPermissions = true
					print("\n\nUnable to mark a message as read. Please make sure you enable Write permissions on the ConversationKitMessage object for all Authenticated users.\n\n")
				}
			}
		}
	}
	
	override func readFromManagedObject(object: ManagedCloudObject) {
		super.readFromManagedObject(object)
		if let object = object as? MessageObject {
			self.speaker = object.speaker?.speaker
			self.listener = object.listener?.speaker
			self.content = object.content ?? ""
			self.needsCloudSave = object.needsCloudSave
			self.spokenAt = object.spokenAt ?? NSDate()
			self.readAt = object.readAt
		}
	}
	
	override func readFromCloudKitRecord(record: CKRecord) {
		super.readFromCloudKitRecord(record)
		
		self.content = record["content"] as? String ?? ""
		self.spokenAt = record["spokenAt"] as? NSDate ?? NSDate()
		self.readAt = record["readAt"] as? NSDate
		
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
			record["speakerName"] = self.speaker?.name ?? ""
			record["speakers"] = [speakerID, listenerID]
			if self.readAt != nil { record["readAt"] = self.readAt }
			return true
		}
		return self.needsCloudSave
	}
	
	override func writeToManagedObject(object: ManagedCloudObject) {
		guard let messageObject = object as? MessageObject else { return }
		
		messageObject.content = self.content
		messageObject.speaker = self.speaker?.objectInContext(object.moc!) as? SpeakerObject
		messageObject.listener = self.listener?.objectInContext(object.moc!) as? SpeakerObject
		messageObject.spokenAt = self.spokenAt
		messageObject.readAt = self.readAt
	}
	
	internal override class var recordName: String { return "ConversationKitMessage" }
	internal override class var entityName: String { return "Message" }

	internal override var canSaveToCloud: Bool {
		return self.speaker != nil && self.listener != nil
	}
	
	public override func delete() {
		self.conversation?.removeMessage(self)
		super.delete()
	}
}

public func <(lhs: Message, rhs: Message) -> Bool {
	return lhs.spokenAt.timeIntervalSinceReferenceDate < rhs.spokenAt.timeIntervalSinceReferenceDate
}


internal class MessageObject: ManagedCloudObject {
	@NSManaged var content: String?
	@NSManaged var speaker: SpeakerObject?
	@NSManaged var listener: SpeakerObject?
	@NSManaged var spokenAt: NSDate?
	@NSManaged var readAt: NSDate?
	internal override class var entityName: String { return "Message" }
}