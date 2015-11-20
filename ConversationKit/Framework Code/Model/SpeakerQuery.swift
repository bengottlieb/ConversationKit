//
//  SpeakerQuery.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/20/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import Foundation
import CloudKit

public class SpeakerQuery: NSObject {
	let predicate: NSPredicate
	let query: CKQuery
	var queryOperation: CKQueryOperation!
	
	public var found: [Speaker] = []
	
	public init(tag: String) {
		predicate = NSPredicate(format: "tags contains %@", tag)
		query = CKQuery(recordType: Speaker.recordName, predicate: predicate)
		super.init()
	}
	
	public func start(completion: ([Speaker]) -> Void) {
		if self.queryOperation != nil { return }
		
		self.queryOperation = CKQueryOperation(query: query)
		self.queryOperation.recordFetchedBlock = { record in
			self.found.append(Speaker.speakerFromRecord(record))
		}
		
		self.queryOperation.queryCompletionBlock = { cursor, error in
			completion(self.found)
		}
		
		Cloud.instance.database.addOperation(queryOperation)
	}
	
	public func cancel() {
		self.queryOperation?.cancel()
		self.queryOperation = nil
	}
}