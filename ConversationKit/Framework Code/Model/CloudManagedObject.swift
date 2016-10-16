//
//  CloudManagedObject.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/16/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

open class CloudObject: NSObject {
	internal var needsCloudSave = false
	internal var hasSavedToCloud = false
	
	internal static var saveDispatchQueue = DispatchQueue(label: "ConversationKitSaveQueue", attributes: [])
	internal static weak var saveTimer: Timer?
	internal static var queuedObjects: Set<CloudObject> = []
	internal func queueForSaving() {
		CloudObject.saveDispatchQueue.async {
			CloudObject.queuedObjects.insert(self)
			Utilities.mainThread {
				CloudObject.saveTimer?.invalidate()
				CloudObject.saveTimer = Timer.scheduledTimer(timeInterval: 0.2, target: CloudObject.self, selector: #selector(CloudObject.saveQueuedObjects), userInfo: nil, repeats: false)
			}
		}
	}
	internal static func saveQueuedObjects(timer: Timer) {
		let objects = self.queuedObjects
		self.saveTimer?.invalidate()
		self.queuedObjects = []
		
		DataStore.instance.importBlock { moc in
			for object in objects {
				object.saveManagedObject(inContext: moc)
			}
			
			moc.safeSave(toDisk: false)
		}
	}
	
	open func save(_ completion: ((NSError?) -> Void)? = nil) {
		self.queueForSaving()
		self.saveToCloudKit { error in
			completion?(error)
		}
	}
	
	internal var cloudKitRecordID: CKRecordID?
	internal var recordID: NSManagedObjectID?
	
	internal class var recordName: String { return "" }
	internal class var entityName: String { return "" }
	
	func write(toObject object: ManagedCloudObject) {
	}

	func write(toCloud record: CKRecord) -> Bool {		//return true if any changes were made
		return false
	}
	
	func read(fromCloud record: CKRecord) {
		self.cloudKitRecordID = record.recordID
	}
	
	func read(fromObject object: ManagedCloudObject) {
		self.recordID = object.objectID
		if let name = object.cloudKitRecordIDName {
			self.cloudKitRecordID = CKRecordID(recordName: name)
		}
	}
	
	var canSaveToCloud: Bool { return true }
	
	open func delete() {
		self.deleteFromiCloud()
		self.deleteFromCoreData()
	}
	
	open func deleteFromCoreData(_ completion: ((Bool) -> Void)? = nil) {
		if let recordID = self.recordID {
			DataStore.instance.importBlock { moc in
				if let object = try? moc.existingObject(with: recordID) {
					moc.delete(object)
					moc.safeSave(toDisk: false)
					completion?(true)
					return
				}
			}
			completion?(false)
		} else {
			completion?(false)
		}
	}
	
	open func deleteFromiCloud(_ completion: ((Bool) -> Void)? = nil) {
		if let recordID = self.cloudKitRecordID {
			Cloud.instance.database.delete(withRecordID: recordID) { recordID, error in
				if let error = error {
					ConversationKit.log("Failed to delete \(type(of: self).recordName) \(recordID)", error: error)
				}
				completion?(error == nil)
			}
		} else {
			completion?(false)
		}
	}
}

internal extension CloudObject {
	func refreshFromCloud(_ completion: ((Bool) -> Void)? = nil) {
		guard let recordID = self.cloudKitRecordID else { completion?(false); return }
		
		ConversationKit.instance.networkActivityUsageCount += 1
		Cloud.instance.database.fetch(withRecordID: recordID) { record, error in
			if (error != nil) { ConversationKit.log("Problem refreshing record \(self)", error: error) }
			if let record = record { self.loadWithCloudKitRecord(record, forceSave: true) }
			completion?(record != nil)
			ConversationKit.instance.networkActivityUsageCount -= 1
		}
	}
	
	func loadWithCloudKitRecord(_ record: CKRecord, forceSave: Bool = false, inContext moc: NSManagedObjectContext? = nil) {
		let isNew = self.recordID == nil || forceSave
		self.cloudKitRecordID = record.recordID
		self.read(fromCloud: record)
		
		if isNew {
			self.saveManagedObject(inContext: moc)
		}
	}
	
	func loadWithManagedObject(_ object: ManagedCloudObject) {
		self.needsCloudSave = object.needsCloudSave
		self.recordID = object.objectID
		if let cloudRecordName = object.cloudKitRecordIDName {
			self.hasSavedToCloud = true
			self.cloudKitRecordID = CKRecordID(recordName: cloudRecordName)
		}
		
		self.read(fromObject: object)
	}
	
	func saveToCloudKit(_ completion: ((NSError?) -> Void)?) {
		if !self.canSaveToCloud{ completion?(NSError(conversationKitError: .cloudSaveNotAllowed)); return }
		if !self.needsCloudSave { completion?(nil); return }
		
		guard let recordID = self.cloudKitRecordID else { fatalError("no cloudkit record id found") }
		Cloud.instance.database.fetch(withRecordID: recordID) { record, error in
			let actual = record ?? self.createNewCloudKitRecord(recordID)

			if self.write(toCloud: actual) {
				ConversationKit.instance.networkActivityUsageCount += 1
				Cloud.instance.database.save(actual, completionHandler: { record, error in
					if (error != nil) { ConversationKit.log("Problem saving record \(self)", error: error) }
					
					if let saved = record {
						self.hasSavedToCloud = true
						self.cloudKitRecordID = saved.recordID
						self.needsCloudSave = false
						self.saveManagedObject(completion: completion)
					} else {
						completion?(error as NSError?)
					}
					ConversationKit.instance.networkActivityUsageCount -= 1
				}) 
			} else {
				self.needsCloudSave = false
				self.saveManagedObject(completion: completion)
			}
		}
	}
	
	func createNewCloudKitRecord(_ recordID: CKRecordID) -> CKRecord {
		let record = CKRecord(recordType: type(of: self).recordName, recordID: recordID)
		return record
	}
}

internal extension CloudObject {
	func saveManagedObject(inContext ctx: NSManagedObjectContext? = nil, completion: ((NSError?) -> Void)? = nil) {
		let shouldSave = ctx == nil
		
		let block = { (moc: NSManagedObjectContext) in
			let localRecord: ManagedCloudObject?
			if let recordID = self.recordID {
				localRecord = moc.object(with: recordID) as? ManagedCloudObject
			} else {
				localRecord = moc.insert(type(of: self).entityName) as? ManagedCloudObject
			}
			guard let record = localRecord else { return }
			
			if !self.needsCloudSave { record.cloudKitRecordIDName = self.cloudKitRecordID?.recordName }
			record.needsCloudSave = self.needsCloudSave
			
			self.write(toObject: record)
			self.recordID = record.objectID
			if shouldSave { moc.safeSave(toDisk: true) }
			completion?(nil)
		}
		
		if let moc = ctx {
			block(moc)
		} else {
			DataStore.instance.importBlock(block)
		}
	}
	
	func objectInContext(_ moc: NSManagedObjectContext) -> ManagedCloudObject? {
		if let id = self.recordID { return moc.object(with: id) as? ManagedCloudObject }
		return nil
	}
}

extension CloudObject {
}

class ManagedCloudObject: NSManagedObject {
	@NSManaged var cloudKitRecordIDName: String?
	@NSManaged var needsCloudSave: Bool

//	public override func setValue(value: AnyObject?, forKey key: String) {
//		if let value = value as? NSObject {
//			let oldValue = self.valueForKey(key) as? NSObject
//			
//			super.setValue(value, forKey: key)
//			if value != oldValue { self.needsCloudSave = true }
//		} else {
//			super.setValue(value, forKey: key)
//		}
//	}
}
