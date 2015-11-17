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
		object.cloudKitRecordIDName = self.cloudKitRecordID?.recordName
		object.needsCloudSave = false
	}

	func writeToCloudKitRecord(record: CKRecord) -> Bool {
		return false
	}
	
	func loadFromCloudKitRecord(record: CKRecord) {
		
	}
	
}

internal extension CloudObject {
	func saveToCloudKit(completion: ((Bool) -> Void)?) {
		if !self.needsCloudSave {
			completion?(true)
			return
		}
		
		if let recordID = self.cloudKitRecordID {
			Cloud.instance.database.fetchRecordWithID(recordID) { record, error in
				if let actual = record {
					self.saveToCloudKitRecord(actual, completion: completion)
				} else {
					Cloud.instance.reportError(error, note: "Unable to fetch existing record")
					completion?(false)
				}
			}
		} else if let record = self.createNewCloudKitRecord() {
			self.saveToCloudKitRecord(record, completion: completion)
		} else {
			Cloud.instance.reportError(NSError(domain: "Data", code: 1, userInfo: nil), note: "Unable to create a new speaker record")
			completion?(false)
		}
	}
	
	func createNewCloudKitRecord() -> CKRecord? {
		let record = CKRecord(recordType: self.dynamicType.recordName)
		return record
	}
	
	func saveToCloudKitRecord(record: CKRecord, completion: ((Bool) -> Void)?) {
		if self.writeToCloudKitRecord(record) {
			Cloud.instance.database.saveRecord(record) { record, error in
				Cloud.instance.reportError(error, note: "Problem saving record \(self)")
				
				if let actual = record {
					self.cloudKitRecordID = actual.recordID
					self.saveManagedObject { object in
						self.writeToManagedObject(object)
					}
				}
				completion?(error == nil)
			}
		} else {
			completion?(false)
		}
	}
}

internal extension CloudObject {
	func saveManagedObject(block: (ManagedCloudObject) -> Void) {
		DataStore.instance.importBlock { moc in
			let localRecord: ManagedCloudObject?
			if let recordID = self.recordID {
				localRecord = moc.objectWithID(recordID) as? ManagedCloudObject
			} else {
				localRecord = moc.insert(self.dynamicType.entityName) as? ManagedCloudObject
			}
			guard let record = localRecord else { return }
			
			block(record)
			moc.safeSave()
		}
	}
}

public class ManagedCloudObject: NSManagedObject {
	@NSManaged public var cloudKitRecordIDName: String?
	@NSManaged public var needsCloudSave: Bool

	
	public override func setValue(value: AnyObject?, forKey key: String) {
		if let value = value as? NSObject {
			let oldValue = self.valueForKey(key) as? NSObject
			
			super.setValue(value, forKey: key)
			if value != oldValue { self.needsCloudSave = true }
		} else {
			super.setValue(value, forKey: key)
		}
	}
}