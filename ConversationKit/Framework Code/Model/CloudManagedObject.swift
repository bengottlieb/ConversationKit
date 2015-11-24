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

public class CloudObject: NSObject {
	internal var needsCloudSave = false
	internal var hasSavedToCloud = false
	
	public func save(completion: ((Bool) -> Void)? = nil) {
		self.saveManagedObject { savedToDisk in
			self.saveToCloudKit { savedToCloud in
				completion?(savedToCloud && savedToDisk)
			}
		}
	}
	
	internal var cloudKitRecordID: CKRecordID?
	internal var recordID: NSManagedObjectID?
	
	internal class var recordName: String { return "" }
	internal class var entityName: String { return "" }
	
	func writeToManagedObject(object: ManagedCloudObject) {
	}

	func writeToCloudKitRecord(record: CKRecord) -> Bool {		//return true if any changes were made
		return false
	}
	
	func readFromCloudKitRecord(record: CKRecord) {
		self.cloudKitRecordID = record.recordID
	}
	
	func readFromManagedObject(object: ManagedCloudObject) {
		self.recordID = object.objectID
		if let name = object.cloudKitRecordIDName {
			self.cloudKitRecordID = CKRecordID(recordName: name)
		}
	}
	
	var canSaveToCloud: Bool { return true }
	
	public func delete() {
		self.deleteFromiCloud()
		self.deleteFromCoreData()
	}
	
	public func deleteFromCoreData(completion: ((Bool) -> Void)? = nil) {
		if let recordID = self.recordID {
			DataStore.instance.importBlock { moc in
				if let object = try? moc.existingObjectWithID(recordID) {
					moc.deleteObject(object)
					moc.safeSave()
					completion?(true)
					return
				}
			}
			completion?(false)
		} else {
			completion?(false)
		}
	}
	
	public func deleteFromiCloud(completion: ((Bool) -> Void)? = nil) {
		if let recordID = self.cloudKitRecordID {
			Cloud.instance.database.deleteRecordWithID(recordID) { recordID, error in
				if let error = error {
					ConversationKit.log("Failed to delete \(self.dynamicType.recordName) \(recordID): \(error)")
				}
				completion?(error == nil)
			}
		} else {
			completion?(false)
		}
	}
}

internal extension CloudObject {
	func refreshFromCloud(completion: ((Bool) -> Void)? = nil) {
		guard let recordID = self.cloudKitRecordID else { completion?(false); return }
		
		ConversationKit.instance.networkActivityUsageCount++
		Cloud.instance.database.fetchRecordWithID(recordID) { record, error in
			Cloud.instance.reportError(error, note: "Problem refreshing record \(self)")
			if let record = record { self.loadWithCloudKitRecord(record, forceSave: true) }
			completion?(record != nil)
			ConversationKit.instance.networkActivityUsageCount--
		}
	}
	
	func loadWithCloudKitRecord(record: CKRecord, forceSave: Bool = false, inContext moc: NSManagedObjectContext? = nil) {
		let isNew = self.recordID == nil || forceSave
		self.cloudKitRecordID = record.recordID
		self.readFromCloudKitRecord(record)
		
		if isNew {
			self.saveManagedObject(inContext: moc)
		}
	}
	
	func loadWithManagedObject(object: ManagedCloudObject) {
		self.needsCloudSave = object.needsCloudSave
		self.recordID = object.objectID
		if let cloudRecordName = object.cloudKitRecordIDName {
			self.hasSavedToCloud = true
			self.cloudKitRecordID = CKRecordID(recordName: cloudRecordName)
		}
		
		self.readFromManagedObject(object)	
	}
	
	func saveToCloudKit(completion: ((Bool) -> Void)?) {
		if !self.canSaveToCloud{ completion?(false); return }
		if !self.needsCloudSave { completion?(true); return }
		
		guard let recordID = self.cloudKitRecordID else { fatalError("no cloudkit record id found") }
		Cloud.instance.database.fetchRecordWithID(recordID) { record, error in
			let actual = record ?? self.createNewCloudKitRecord(recordID)

			if self.writeToCloudKitRecord(actual) {
				ConversationKit.instance.networkActivityUsageCount++
				Cloud.instance.database.saveRecord(actual) { record, error in
					Cloud.instance.reportError(error, note: "Problem saving record \(self)")
					
					if let saved = record {
						self.hasSavedToCloud = true
						self.cloudKitRecordID = saved.recordID
						self.needsCloudSave = false
						self.saveManagedObject(completion: completion)
					} else {
						completion?(false)
					}
					ConversationKit.instance.networkActivityUsageCount--
				}
			} else {
				self.needsCloudSave = false
				self.saveManagedObject(completion: completion)
			}
		}
	}
	
	func createNewCloudKitRecord(recordID: CKRecordID) -> CKRecord {
		let record = CKRecord(recordType: self.dynamicType.recordName, recordID: recordID)
		return record
	}
}

internal extension CloudObject {
	func saveManagedObject(inContext ctx: NSManagedObjectContext? = nil, completion: ((Bool) -> Void)? = nil) {
		let shouldSave = ctx == nil
		
		let block = { (moc: NSManagedObjectContext) in
			let localRecord: ManagedCloudObject?
			if let recordID = self.recordID {
				localRecord = moc.objectWithID(recordID) as? ManagedCloudObject
			} else {
				localRecord = moc.insert(self.dynamicType.entityName) as? ManagedCloudObject
			}
			guard let record = localRecord else { return }
			
			if !self.needsCloudSave { record.cloudKitRecordIDName = self.cloudKitRecordID?.recordName }
			record.needsCloudSave = self.needsCloudSave
			
			self.writeToManagedObject(record)
			self.recordID = record.objectID
			if shouldSave { moc.safeSave() }
			completion?(true)
		}
		
		if let moc = ctx {
			block(moc)
		} else {
			DataStore.instance.importBlock(block)
		}
	}
	
	func objectInContext(moc: NSManagedObjectContext) -> ManagedCloudObject? {
		if let id = self.recordID { return moc.objectWithID(id) as? ManagedCloudObject }
		return nil
	}
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