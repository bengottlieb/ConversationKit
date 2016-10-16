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
import UIKit

open class Speaker: CloudObject {
	open static var maxImageSize = CGSize(width: 120, height: 120)
	public typealias SpeakerRef = String
	open var identifier: String? { didSet {
		if self.identifier != oldValue {
			self.needsCloudSave = self.isLocalSpeaker
			self.cloudKitRecordID = Speaker.cloudKitRecordID(from: self.identifier)
		}
	}}
	var pending: PendingMessage?
	open var name: String? { didSet { if self.name != oldValue { self.needsCloudSave = self.isLocalSpeaker }}}
	open var tags: Set<String> = [] { didSet { if self.tags != oldValue { self.needsCloudSave = self.isLocalSpeaker }}}
	open var isLocalSpeaker = false
	open class func allKnownSpeakers() -> [Speaker] { return Array(self.knownSpeakers) }
	open var avatarImage: UIImage? { didSet {
		self.needsCloudSave = self.isLocalSpeaker
	}}
	open var avatarImageLocalURL: URL? { return self.avatarImageFileName.isEmpty ? nil : DataStore.instance.imagesCacheURL.appendingPathComponent(self.avatarImageFileName) }

	open func store(avatar image: UIImage?) {
		if var newImage = image {
			if newImage.size.width > Speaker.maxImageSize.width || newImage.size.height > Speaker.maxImageSize.height {
				let scale = min(Speaker.maxImageSize.width / newImage.size.width, Speaker.maxImageSize.height / newImage.size.height)
				let bounds = CGRect(x: 0, y: 0, width: newImage.size.width * scale, height: newImage.size.height * scale)
				UIGraphicsBeginImageContextWithOptions(bounds.size, false, 2.0)
				newImage.draw(in: bounds)
				newImage = UIGraphicsGetImageFromCurrentImageContext()!
				UIGraphicsEndImageContext()
			}
			if let data = UIImageJPEGRepresentation(newImage, 0.9) {
				self.avatarImageFileName = data.sha255Hash + ".jpg"
				
				try? data.write(to: self.avatarImageLocalURL!, options: [.atomic])
				self.needsCloudSave = true
				self.avatarImage = newImage
			}
		} else {
			self.avatarImage = nil
		}
	}
	
	public func createBarButtonItem(target: NSObject, action: Selector) -> UIBarButtonItem? {
		guard let local = Speaker.localSpeaker else { return nil }
		return self.conversation(with: local).createBarButtonItem(target: target, action: action)
	}

	
	open static var localSpeaker: Speaker?
	open class func speaker(withIdentifier identifier: String?, name: String? = nil) -> Speaker? {
		if let identifier = identifier, let cloudID = Speaker.cloudKitRecordID(from: identifier), let existing = self.speaker(fromCloudID: cloudID) { return existing }
		
		let newSpeaker = Speaker()
		newSpeaker.identifier = identifier
		newSpeaker.name = name
		self.add(known: newSpeaker)
		newSpeaker.refreshFromCloud()
		newSpeaker.saveManagedObject()
		return newSpeaker
	}
	
	@discardableResult open func send(message content: String, completion: ((Bool) -> Void)? = nil) -> Message? {
		guard let local = Speaker.localSpeaker else { return nil }
		let message = Message(speaker: local, listener: self, content: content)
		
		message.saveManagedObject()
		message.saveToCloudKit { error in
			completion?(error == nil)
		}
		
		Conversation.existingConversationWith(self)?.addMessage(message, from: .new)
		Utilities.postNotification(ConversationKit.notifications.postedNewMessage, object: message)
		
		return message
	}
	
	open var speakerRef: SpeakerRef? { return self.identifier }
	open class func speaker(fromRef ref: SpeakerRef?) -> Speaker? {
		if let reference = ref {
			for speaker in self.knownSpeakers {
				if speaker.identifier == reference { return speaker }
			}
		}
		return nil
	}
	
	open func conversation(with other: Speaker) -> Conversation {
		return Conversation.conversationBetween([other, self])
	}

	var cloudKitReference: CKReference? { if let recordID = self.cloudKitRecordID { return CKReference(recordID: recordID, action: .none) } else { return nil } }
	
	static var knownSpeakersLoaded = false
	class func loadCachedSpeakers(completion: @escaping () -> Void) {
		if self.knownSpeakersLoaded {
			completion()
			return
		}
		self.knownSpeakersLoaded = true
		
		ConversationKit.queue.sync { self.knownSpeakers = [] }
		let moc = DataStore.instance.privateContext
		moc.perform {
			let speakers: [SpeakerObject] = moc.allObjects()
			for record in speakers {
				let speaker = Speaker()
				speaker.read(fromObject: record)
				if speaker.isLocalSpeaker { self.localSpeaker = speaker }
				self.add(known: speaker)
			}
			
			ConversationKit.queue.sync {
				if self.localSpeaker == nil {
					let speaker = Speaker()
					speaker.isLocalSpeaker = true
					//speaker.saveManagedObject(inContext: moc)
					self.knownSpeakers.insert(speaker)
					self.localSpeaker = speaker
				}
				
				Utilities.postNotification(ConversationKit.notifications.loadedKnownSpeakers)
				completion()
			}
		}
	}
	
	static var knownSpeakers = Set<Speaker>()
	class func add(known spkr: Speaker) {
		_ = ConversationKit.queue.sync { self.knownSpeakers.insert(spkr) } }
	class func cloudKitRecordID(from identifier: String?) -> CKRecordID? {
		if let ident = identifier {
			return CKRecordID(recordName: "Speaker: " + ident)
		}
		return nil
	}
	
	internal class func speaker(fromCloudID recordID: CKRecordID) -> Speaker? {
		for speaker in self.knownSpeakers {
			if speaker.cloudKitRecordID == recordID { return speaker }
		}
		return nil
	}
	
	internal class func speaker(fromCloudRecord record: CKRecord, inContext moc: NSManagedObjectContext? = nil) -> Speaker {
		for speaker in self.knownSpeakers {
			if speaker.cloudKitRecordID == record.recordID {
				speaker.loadWithCloudKitRecord(record, inContext: moc)
				speaker.saveManagedObject(inContext: moc)
				return speaker
			}
		}
		
		let speaker = Speaker()
		speaker.loadWithCloudKitRecord(record, inContext: moc)
		self.add(known: speaker)
		Utilities.postNotification(ConversationKit.notifications.foundNewSpeaker, object:	speaker)
		return speaker
	}

	internal class func speaker(fromID identifier: String?) -> Speaker? {
		for speaker in self.knownSpeakers {
			if speaker.identifier == identifier {
				return speaker
			}
		}
		return nil
	}
	
	internal class func loadSpeaker(fromCloudID recordID: CKRecordID, completion: ((Speaker?) -> Void)?) -> Speaker? {
		Cloud.instance.database.fetch(withRecordID: recordID) { record, error in
			if let record = record {
				let speaker = Speaker()
				speaker.loadWithCloudKitRecord(record)
				Speaker.add(known: speaker)
				
				completion?(speaker)
			} else {
				if (error != nil) { ConversationKit.log("Problem loading speaker with ID \(recordID)", error: error) }
				completion?(nil)
			}
		}
		
		return nil
	}
	
	internal var avatarImageFileName = ""
	
	override func read(fromCloud record: CKRecord) {
		super.read(fromCloud: record)
		self.identifier = record["identifier"] as? String
		self.name = record["name"] as? String
		self.tags = Set(record["tags"] as? [String] ?? [])
		
		if self.isLocalSpeaker {
			Utilities.postNotification(ConversationKit.notifications.localSpeakerUpdated)
		}
		
		if let asset = record["avatarImage"] as? CKAsset, let data = try? Data(contentsOf: asset.fileURL) {
			self.avatarImage = UIImage(data: data)
			self.avatarImageFileName = asset.fileURL.lastPathComponent + ".jpg"
			let url = DataStore.instance.imagesCacheURL.appendingPathComponent(self.avatarImageFileName)
			try? data.write(to: url, options: [.atomic])
		}
	}
	
	override func write(toCloud record: CKRecord) -> Bool {
		if !self.isLocalSpeaker { return false }
		let recordTags = Set(record["tags"] as? [String] ?? [])
		
		var avatarChanged = false
		if let recordAvatar = record["avatarImage"] as? CKAsset {
			avatarChanged = self.avatarImageFileName != recordAvatar.fileURL.lastPathComponent
		} else {
			avatarChanged = !self.avatarImageFileName.isEmpty
		}
		
		if (record["identifier"] as? String) == self.identifier && (record["name"] as? String) == self.name && recordTags == self.tags && !avatarChanged { return self.needsCloudSave }
		
		record["identifier"] = self.identifier as CKRecordValue?
		record["name"] = self.name as CKRecordValue?
		if !self.tags.isEmpty { record["tags"] = Array(self.tags) as NSArray }
		if let url = self.avatarImageLocalURL {
			record["avatarImage"] = CKAsset(fileURL: url)
		} else {
			record["avatarImage"] = nil
		}
		return true
	}
	
	override func read(fromObject object: ManagedCloudObject) {
		guard let spkr = object as? SpeakerObject else { return }
		
		super.read(fromObject: object)
		self.identifier = spkr.identifier
		self.name = spkr.name
		self.isLocalSpeaker = spkr.isLocalSpeaker
		self.tags = Set(spkr.tags ?? [])
		self.pending = PendingMessage(speaker: self, cachedPendingAt: spkr.lastPendingAt)
		
		if let filename = spkr.avatarImageFilename, let data = try? Data(contentsOf: DataStore.instance.imagesCacheURL.appendingPathComponent(filename)) {
			self.avatarImage = UIImage(data: data)
			self.avatarImageFileName = filename
			self.needsCloudSave = self.cloudKitRecordID == nil && self.isLocalSpeaker
		} else {
			self.avatarImageFileName = ""
		}
	}
	
	override func write(toObject object: ManagedCloudObject) {
		guard let speakerObject = object as? SpeakerObject else { return }
		speakerObject.name = self.name
		speakerObject.identifier = self.identifier
		speakerObject.isLocalSpeaker = self.isLocalSpeaker
		speakerObject.lastPendingAt = self.pending?.pendingAt as Date?
		speakerObject.tags = self.tags.count > 0 ? Array(self.tags) : nil
	
		if !self.avatarImageFileName.isEmpty {
			speakerObject.avatarImageFilename = self.avatarImageFileName
		} else {
			speakerObject.avatarImageFilename = nil
		}
	}

	internal override class var recordName: String { return "ConversationKitSpeaker" }
	internal override class var entityName: String { return "Speaker" }

	internal override var canSaveToCloud: Bool { return self.identifier != nil }
	
	class func clearKnownSpeakers(_ completion: @escaping () -> Void) {
		ConversationKit.queue.async {
			self.knownSpeakers = Set<Speaker>()
			self.localSpeaker = nil
			self.knownSpeakersLoaded = false
			completion()
		}
	}
}

extension Speaker {
	override open var description: String {
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
	@NSManaged var avatarImageFilename: String?
	@NSManaged var tags: [String]?
	@NSManaged var lastPendingAt: Date?
	
	internal override class var entityName: String { return "Speaker" }
	var speaker: Speaker? { return Speaker.speaker(withIdentifier: self.identifier, name: self.name) }
}
