//
//  Speaker.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public class Speaker: CloudObject {
	public typealias SpeakerRef = String
	public var identifier: String? { didSet {
		if self.identifier != oldValue {
			self.needsCloudSave = self.isLocalSpeaker
			self.cloudKitRecordID = Speaker.cloudKitRecordIDFromIdentifier(self.identifier)
		}
	}}
	public var name: String? { didSet { if self.name != oldValue { self.needsCloudSave = self.isLocalSpeaker }}}
	public var tags: Set<String> = [] { didSet { if self.tags != oldValue { self.needsCloudSave = self.isLocalSpeaker }}}
	public var isLocalSpeaker = false
	public class func allKnownSpeakers() -> [Speaker] { return Array(self.knownSpeakers) }
	
	public static var localSpeaker: Speaker!
	public class func speakerWithIdentifier(identifier: String, name: String? = nil) -> Speaker {
		if let cloudID = Speaker.cloudKitRecordIDFromIdentifier(identifier), existing = self.speakerFromRecordID(cloudID) { return existing }
		
		let newSpeaker = Speaker()
		newSpeaker.identifier = identifier
		newSpeaker.name = name
		self.addKnownSpeaker(newSpeaker)
		newSpeaker.refreshFromCloud()
		newSpeaker.saveManagedObject()
		return newSpeaker
	}
	
	public func sendMessage(content: String, completion: ((Bool) -> Void)?) {
		let message = Message(speaker: Speaker.localSpeaker, listener: self, content: content)
		
		message.saveManagedObject()
		message.saveToCloudKit(completion)
	}
	
	public var speakerRef: SpeakerRef? { return self.identifier }
	public class func speakerFromSpeakerRef(ref: SpeakerRef?) -> Speaker? {
		if let reference = ref {
			for speaker in self.knownSpeakers {
				if speaker.identifier == reference { return speaker }
			}
		}
		return nil
	}
	
	public func conversationWith(other: Speaker) -> Conversation {
		return Conversation.conversationWithSpeaker(self, listener: other)
	}
	
	var cloudKitReference: CKReference? { if let recordID = self.cloudKitRecordID { return CKReference(recordID: recordID, action: .None) } else { return nil } }
	
	static var knownSpeakersLoaded = false
	class func loadCachedSpeakers(completion: () -> Void) {
		if self.knownSpeakersLoaded {
			completion()
			return
		}
		self.knownSpeakersLoaded = true
		DataStore.instance.importBlock { moc in
			let speakers: [SpeakerObject] = moc.allObjects()
			for record in speakers {
				let speaker = Speaker()
				speaker.readFromManagedObject(record)
				if speaker.isLocalSpeaker { self.localSpeaker = speaker }
				self.knownSpeakers.insert(speaker)
			}
			
			if self.localSpeaker == nil {
				let speaker = Speaker()
				speaker.isLocalSpeaker = true
				speaker.saveManagedObject()
				Speaker.addKnownSpeaker(speaker)
				self.localSpeaker = speaker
			}
			
			Utilities.postNotification(ConversationKit.notifications.loadedKnownSpeakers)
			completion()
		}
	}
	
	static var knownSpeakers = Set<Speaker>()
	class func addKnownSpeaker(spkr: Speaker) { dispatch_sync(ConversationKit.instance.queue) { self.knownSpeakers.insert(spkr) } }
	class func cloudKitRecordIDFromIdentifier(identifier: String?) -> CKRecordID? {
		if let ident = identifier {
			return CKRecordID(recordName: "Speaker: " + ident)
		}
		return nil
	}
	
	internal class func speakerFromRecordID(recordID: CKRecordID) -> Speaker? {
		for speaker in self.knownSpeakers {
			if speaker.cloudKitRecordID == recordID { return speaker }
		}
		return nil
	}
	
	internal class func speakerFromRecord(record: CKRecord) -> Speaker {
		for speaker in self.knownSpeakers {
			if speaker.cloudKitRecordID == record.recordID {
				speaker.loadWithCloudKitRecord(record)
				speaker.saveManagedObject()
				return speaker
			}
		}
		
		let speaker = Speaker()
		speaker.loadWithCloudKitRecord(record)
		self.addKnownSpeaker(speaker)
		Utilities.postNotification(ConversationKit.notifications.foundNewSpeaker, object:	speaker)
		return speaker
	}

	internal class func loadSpeakerFromRecordID(recordID: CKRecordID, completion: ((Speaker?) -> Void)?) -> Speaker? {
		Cloud.instance.database.fetchRecordWithID(recordID) { record, error in
			if let record = record {
				let speaker = Speaker()
				speaker.loadWithCloudKitRecord(record)
				Speaker.addKnownSpeaker(speaker)
				
				completion?(speaker)
			} else {
				Cloud.instance.reportError(error, note: "Problem loading speaker with ID \(recordID)")
				completion?(nil)
			}
		}
		
		return nil
	}
	
	override func readFromCloudKitRecord(record: CKRecord) {
		self.identifier = record["identifier"] as? String
		self.name = record["name"] as? String
		self.tags = Set(record["tags"] as? [String] ?? [])
		
		if self.isLocalSpeaker {
			Utilities.postNotification(ConversationKit.notifications.localSpeakerUpdated)
		}
	}
	
	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		if !self.isLocalSpeaker { return false }
		let recordTags = Set(record["tags"] as? [String] ?? [])
		if (record["identifier"] as? String) == self.identifier && (record["name"] as? String) == self.name && recordTags == self.tags { return self.needsCloudSave }
		
		record["identifier"] = self.identifier
		record["name"] = self.name
		record["tags"] = self.tags.count > 0 ? Array(self.tags): nil
		return true
	}
	
	override func readFromManagedObject(object: ManagedCloudObject) {
		guard let spkr = object as? SpeakerObject else { return }
		
		self.recordID = spkr.objectID
		self.identifier = spkr.identifier
		self.name = spkr.name
		self.isLocalSpeaker = spkr.isLocalSpeaker
		self.tags = Set(spkr.tags ?? [])
	}
	
	override func writeToManagedObject(object: ManagedCloudObject) {
		guard let speakerObject = object as? SpeakerObject else { return }
		speakerObject.name = self.name
		speakerObject.identifier = self.identifier
		speakerObject.isLocalSpeaker = self.isLocalSpeaker
		speakerObject.tags = self.tags.count > 0 ? Array(self.tags) : nil
	}

	internal override class var recordName: String { return "ConversationKitSpeaker" }
	internal override class var entityName: String { return "Speaker" }

	internal override var canSaveToCloud: Bool { return self.identifier != nil }
	
	class func clearKnownSpeakers() {
		self.knownSpeakers.removeAll()
		self.localSpeaker = nil
		self.knownSpeakersLoaded = false
	}
}

public extension Speaker {
	override var description: String {
		return "\(self.name ?? "unnamed"): \(self.identifier ?? "--")"
	}
}

public func ==(lhs: Speaker, rhs: Speaker) -> Bool {
	return lhs.identifier == rhs.identifier
}

internal class SpeakerObject: ManagedCloudObject {
	@NSManaged var identifier: String?
	@NSManaged var name: String?
	@NSManaged var isLocalSpeaker: Bool
	@NSManaged var tags: [String]?
	
	internal override class var entityName: String { return "Speaker" }
	var speaker: Speaker { return Speaker.speakerWithIdentifier(self.identifier!, name: self.name) }
}