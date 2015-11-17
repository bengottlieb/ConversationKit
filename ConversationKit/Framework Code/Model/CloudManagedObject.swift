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

public class CloudManagedObject: NSManagedObject {
	@NSManaged public var cloudKitRecordIDString: String?
	@NSManaged public var needsCloudSave: Bool
	
	var cloudKitRecordID: CKRecordID?
	
	func loadFromCloudKitRecord(record: CKRecord) {
		
	}
	
	func writeToCloudKitRecord(record: CKRecord) -> Bool {
		return false
	}
	
	public override func setValue(value: AnyObject?, forKey key: String) {
		if let value = value as? NSObject {
			let oldValue = self.valueForKey(key) as? NSObject
			
			super.setValue(value, forKey: key)
			if value != oldValue { self.needsCloudSave = true }
		} else {
			super.setValue(value, forKey: key)
		}
	}
	
	func saveToCloudKit(completion: ((Bool) -> Void)?) {
		if !self.needsCloudSave {
			completion?(true)
			return
		}
		
		self.moc?.safeSave()
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
		let record = CKRecord(recordType: self.dynamicType.entityName)
		return record
	}
	
	func saveToCloudKitRecord(record: CKRecord, completion: ((Bool) -> Void)?) {
		if self.writeToCloudKitRecord(record) {
			Cloud.instance.database.saveRecord(record) { record, error in
				Cloud.instance.reportError(error, note: "Problem saving record \(self)")
				
				if let actual = record {
					self.moc?.performBlock {
						self.cloudKitRecordID = actual.recordID
						self.needsCloudSave = false
						self.moc?.safeSave()
					}
				}
				completion?(error == nil)
			}
		} else {
			completion?(false)
		}
	}
}