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
	public var needsCloudSave: Bool = false
	
	internal var cloudKitRecordID: CKRecordID?
	internal var recordID: NSManagedObjectID?
	
	internal var managedObject: ManagedCloudObject?
	internal class var recordName: String { return "" }
	internal class var entityName: String { return "" }
	
	func writeToManagedObject(object: ManagedCloudObject) {
	}

	func writeToCloudKitRecord(record: CKRecord) -> Bool {		//return true if any changes were made
		return false
	}
	
	func readFromCloudKitRecord(record: CKRecord) {
	}
	
	func didCreateFromServerRecord() {
		
	}
	
	var canSaveToCloud: Bool { return true }
}

internal extension CloudObject {
	func refreshFromCloud(completion: ((Bool) -> Void)? = nil) {
		guard let recordID = self.cloudKitRecordID else { completion?(false); return }
		
		Cloud.instance.database.fetchRecordWithID(recordID) { record, error in
			Cloud.instance.reportError(error, note: "Problem refreshing record \(self)")
			if let record = record { self.loadWithCloudKitRecord(record) }
			completion?(record != nil)
		}
	}
	
	func loadWithCloudKitRecord(record: CKRecord) {
		let isNew = self.cloudKitRecordID == nil
		self.cloudKitRecordID = record.recordID
		self.readFromCloudKitRecord(record)
		
		if isNew {
			self.saveManagedObject()
			self.didCreateFromServerRecord()
		}
	}
	
	func saveToCloudKit(completion: ((Bool) -> Void)?) {
		if !self.canSaveToCloud{ completion?(false); return }
		if !self.needsCloudSave { completion?(true); return }
		
		guard let recordID = self.cloudKitRecordID else { fatalError("no cloudkit record id found") }
		Cloud.instance.database.fetchRecordWithID(recordID) { record, error in
			let actual = record ?? self.createNewCloudKitRecord(recordID)

			if self.writeToCloudKitRecord(actual) {
				Cloud.instance.database.saveRecord(actual) { record, error in
					Cloud.instance.reportError(error, note: "Problem saving record \(self)")
					
					if let saved = record {
						self.cloudKitRecordID = saved.recordID
						self.needsCloudSave = false
						self.saveManagedObject(completion)
					} else {
						completion?(false)
					}
				}
			} else {
				self.needsCloudSave = false
				self.saveManagedObject(completion)
			}
		}
	}
	
	func createNewCloudKitRecord(recordID: CKRecordID) -> CKRecord {
		let record = CKRecord(recordType: self.dynamicType.recordName, recordID: recordID)
		return record
	}
}

internal extension CloudObject {
	func saveManagedObject(completion: ((Bool) -> Void)? = nil) {
		DataStore.instance.importBlock { moc in
			let localRecord: ManagedCloudObject?
			if let recordID = self.recordID {
				localRecord = moc.objectWithID(recordID) as? ManagedCloudObject
			} else {
				localRecord = moc.insert(self.dynamicType.entityName) as? ManagedCloudObject
			}
			guard let record = localRecord else { return }
			
			record.cloudKitRecordIDName = self.cloudKitRecordID?.recordName
			record.needsCloudSave = self.needsCloudSave
			
			self.writeToManagedObject(record)
			moc.safeSave()
			completion?(true)
		}
	}
}

public class ManagedCloudObject: NSManagedObject {
	@NSManaged public var cloudKitRecordIDName: String?
	@NSManaged public var needsCloudSave: Bool

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