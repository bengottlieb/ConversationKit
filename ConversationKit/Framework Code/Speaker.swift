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
	public var identifier: String? { didSet {
		if self.identifier != oldValue {
			self.needsCloudSave = true
			self.cloudKitRecordID = Speaker.cloudKitRecordIDFromIdentifier(self.identifier)
		}
	}}
	public var name: String? { didSet { if self.name != oldValue { self.needsCloudSave = true }}}
	public var isLocalSpeaker = false
	
	public static var localSpeaker: Speaker!
	public class func speakerWithIdentifier(identifier: String, name: String? = nil) -> Speaker {
		if let cloudID = Speaker.cloudKitRecordIDFromIdentifier(identifier), existing = self.speakerFromRecordID(cloudID) { return existing }
		
		let newSpeaker = Speaker()
		newSpeaker.identifier = identifier
		newSpeaker.name = name
		self.addKnownSpeaker(newSpeaker)
		newSpeaker.saveManagedObject()
		newSpeaker.saveToCloudKit(nil)
		return newSpeaker
	}
	
	public func sendMessage(content: String, completion: ((Bool) -> Void)?) {
		let message = Message(speaker: Speaker.localSpeaker, listener: self, content: content)
		
		message.saveManagedObject()
		message.saveToCloudKit(completion)
	}
	
	var cloudKitReference: CKReference? { if let recordID = self.cloudKitRecordID { return CKReference(recordID: recordID, action: .None) } else { return nil } }
	
	class func loadCachedSpeakers(completion: () -> Void) {
		DataStore.instance.importBlock { moc in
			let speakers: [SpeakerRecord] = moc.allObjects()
			for record in speakers {
				let speaker = Speaker()
				speaker.readFromManagedObject(record)
				if speaker.isLocalSpeaker { self.localSpeaker = speaker }
				self.knownSpeakers.insert(speaker)
			}
			
			if self.localSpeaker == nil {
				let speaker = Speaker()
				speaker.isLocalSpeaker = true
				speaker.needsCloudSave = false
				speaker.saveManagedObject()
				Speaker.addKnownSpeaker(speaker)
				self.localSpeaker = speaker
			}
			
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
		identifier = record["identifier"] as? String
		name = record["name"] as? String
		
		if self.isLocalSpeaker {
			Utilities.postNotification(ConversationKit.notifications.localSpeakerUpdated)
		}
	}
	
	override func didCreateFromServerRecord() {
		Cloud.instance.pullDownMessages()
	}
	
	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		if (record["identifier"] as? String) == self.identifier && (record["name"] as? String) == self.name { return self.needsCloudSave }
		
		record["identifier"] = self.identifier
		record["name"] = self.name
		return true
	}
	
	override func readFromManagedObject(object: ManagedCloudObject) {
		guard let spkr = object as? SpeakerRecord else { return }
		
		self.recordID = spkr.objectID
		self.identifier = spkr.identifier
		self.name = spkr.name
		self.isLocalSpeaker = spkr.isLocalSpeaker
	}
	
	override func writeToManagedObject(object: ManagedCloudObject) {
		guard let speakerObject = object as? SpeakerRecord else { return }
		speakerObject.name = self.name
		speakerObject.identifier = self.identifier
		speakerObject.isLocalSpeaker = self.isLocalSpeaker
	}

	internal override class var recordName: String { return "Speaker" }
	internal override class var entityName: String { return "SpeakerRecord" }

	internal override var canSaveToCloud: Bool { return self.identifier != nil }
}

public func ==(lhs: Speaker, rhs: Speaker) -> Bool {
	return lhs.identifier == rhs.identifier
}

internal class SpeakerRecord: ManagedCloudObject {
	@NSManaged var identifier: String?
	@NSManaged var name: String?
	@NSManaged var isLocalSpeaker: Bool
}