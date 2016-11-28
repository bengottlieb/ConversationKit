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

open class Message: CloudObject {
	open var content = ""
	open var speaker: Speaker!
	open var listener: Speaker!
	open var spokenAt = Date()
	open var conversation: Conversation?
	open var readAt: Date?
	
	var isUnread: Bool { return (self.speaker?.isLocalSpeaker == false) && self.readAt == nil }
	
	open var displayedContent: String {
		return "\(self.content)"
	}
	
	class func recordExists(_ record: CKRecord, inContext moc: NSManagedObjectContext) -> Bool {
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
		self.spokenAt = Date()
		self.needsCloudSave = true
		self.cloudKitRecordID = CKRecordID(recordName: "Message: \(UUID().uuidString)")
	}
	
	convenience init?(record: CKRecord) {
		self.init()
		
		guard let speakers = record[keys.speakers] as? [String] , speakers.count == 2 else { return nil }
		
		self.read(fromCloud: record)
	}
	
	convenience init(object: MessageObject) {
		self.init()
		
		self.read(fromObject: object)
	}
	
	static var hasRemindedAboutPermissions = false
	open func markAsRead() {
		if self.readAt == nil && !(self.speaker?.isLocalSpeaker ?? true) {
			self.readAt = Date()
			self.needsCloudSave = true
			self.conversation?.updateButtons()
			self.save() { error in
				if let err = error , err.code == 10 && !Message.hasRemindedAboutPermissions && ConversationKit.feedbackLevel != .production {
					Message.hasRemindedAboutPermissions = true
					print("\n\nUnable to mark a message as read. Please make sure you enable Write permissions on the ConversationKitMessage object for all Authenticated users.\n\n")
				}
			}
		}
	}
	
	override func read(fromObject object: ManagedCloudObject) {
		super.read(fromObject: object)
		if let object = object as? MessageObject {
			self.speaker = object.speaker?.speaker
			self.listener = object.listener?.speaker
			self.content = object.content ?? ""
			self.needsCloudSave = object.needsCloudSave
			self.spokenAt = object.spokenAt ?? Date()
			self.readAt = object.readAt
		}
	}
	
	override func read(fromCloud record: CKRecord) {
		super.read(fromCloud: record)
		
		self.content = record[keys.content] as? String ?? ""
		self.spokenAt = record.creationDate ?? record[keys.spokenAt] as? Date ?? Date()
		self.readAt = record[keys.readAt] as? Date
		
		if let speakers = record[keys.speakers] as? [String] , speakers.count == 2 {
			let speaker = Speaker.speaker(withIdentifier: speakers[0]), listener = Speaker.speaker(withIdentifier: speakers[1])

			self.speaker = speaker
			self.listener = listener
		}
	}
	
	struct keys {
		static let spokenAt = "spokenAt"
		static let content = "content"
		static let speakerName = "speakerName"
		static let speakers = "speakers"
		static let readAt = "readAt"
	}
	
	override func write(toCloud record: CKRecord) -> Bool {
		if let speakerID = self.speaker?.identifier, let listenerID = self.listener?.identifier {
			
			record[keys.spokenAt] = self.spokenAt as CKRecordValue?;
			record[keys.content] = self.content as CKRecordValue?
			record[keys.speakerName] = self.speaker?.name as CKRecordValue?? ?? "" as CKRecordValue?
			record[keys.speakers] = [speakerID, listenerID] as NSArray
			if self.readAt != nil { record[keys.readAt] = self.readAt as CKRecordValue? }
			return true
		}
		return self.needsCloudSave
	}
	
	override func write(toObject object: ManagedCloudObject) {
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
	
	open override func delete() {
		self.conversation?.removeMessage(self)
		super.delete()
	}
}

public func <(lhs: Message, rhs: Message) -> Bool {
	return lhs.spokenAt < rhs.spokenAt
}


internal class MessageObject: ManagedCloudObject {
	@NSManaged var content: String?
	@NSManaged var speaker: SpeakerObject?
	@NSManaged var listener: SpeakerObject?
	@NSManaged var spokenAt: Date?
	@NSManaged var readAt: Date?
	internal override class var entityName: String { return "Message" }
}
