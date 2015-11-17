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
	public var identifier: String?
	public var name: String?
	
	override func loadFromCloudKitRecord(record: CKRecord) {
		identifier = record["identifier"] as? String
		name = record["name"] as? String
	}
	
	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		record["identifier"] = self.identifier
		record["name"] = self.name
		return true
	}
}

internal class SpeakerRecord: ManagedCloudObject {
	@NSManaged var identifier: String?
	@NSManaged var name: String?
}