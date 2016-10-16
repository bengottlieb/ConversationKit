//
//  SpeakerQuery.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/20/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

open class SpeakerQuery: NSObject {
	let predicate: NSPredicate
	let query: CKQuery
	var queryOperation: CKQueryOperation!
	let importContext: NSManagedObjectContext
	
	open var found: [Speaker] = []
	
	public init(tag: String) {
		predicate = NSPredicate(format: "tags contains %@", tag)
		query = CKQuery(recordType: Speaker.recordName, predicate: predicate)
		importContext = DataStore.instance.createWorkerContext()
		super.init()
	}
	
	open func start(_ completion: @escaping ([Speaker]) -> Void) {
		if self.queryOperation != nil { return }
		
		ConversationKit.instance.networkActivityUsageCount += 1
		self.queryOperation = CKQueryOperation(query: query)
		self.queryOperation.recordFetchedBlock = { record in
			self.found.append(Speaker.speakerFromRecord(record, inContext: self.importContext))
		}
		
		self.queryOperation.queryCompletionBlock = { cursor, error in
			self.importContext.safeSave(toDisk: false)
			completion(self.found)
			ConversationKit.instance.networkActivityUsageCount -= 1
		}
		
		Cloud.instance.database.add(queryOperation)
	}
	
	open func cancel() {
		self.queryOperation?.cancel()
		self.queryOperation = nil
	}
}
