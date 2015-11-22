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

public class SpeakerQuery: NSObject {
	let predicate: NSPredicate
	let query: CKQuery
	var queryOperation: CKQueryOperation!
	let importContext: NSManagedObjectContext
	
	public var found: [Speaker] = []
	
	public init(tag: String) {
		predicate = NSPredicate(format: "tags contains %@", tag)
		query = CKQuery(recordType: Speaker.recordName, predicate: predicate)
		importContext = DataStore.instance.createWorkerContext()
		super.init()
	}
	
	public func start(completion: ([Speaker]) -> Void) {
		if self.queryOperation != nil { return }
		
		ConversationKit.instance.networkActivityUsageCount++
		self.queryOperation = CKQueryOperation(query: query)
		self.queryOperation.recordFetchedBlock = { record in
			self.found.append(Speaker.speakerFromRecord(record, inContext: self.importContext))
		}
		
		self.queryOperation.queryCompletionBlock = { cursor, error in
			self.importContext.safeSave()
			completion(self.found)
			ConversationKit.instance.networkActivityUsageCount--
		}
		
		Cloud.instance.database.addOperation(queryOperation)
	}
	
	public func cancel() {
		self.queryOperation?.cancel()
		self.queryOperation = nil
	}
}