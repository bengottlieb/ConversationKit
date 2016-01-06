//
//  PendingMessage.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/30/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import Foundation
import CloudKit

extension Cloud {
	
}


class PendingMessage {
	static var recordName = "ConversationKitPending"
	
	let speaker: Speaker!
	var pendingAt: NSDate?
	
	init?(speaker who: Speaker, cachedPendingAt: NSDate?) {
		speaker = who
		pendingAt = cachedPendingAt
		if speaker == nil { return nil }
	}
	
	init(speaker who: Speaker) {
		speaker = who
		pendingAt = NSDate()
		
		self.saveToCloud()
	}
	
	var recordIDName: String? {
		guard let local = Speaker.localSpeaker, localIdent = local.identifier, remoteIdent = self.speaker.identifier else {
			ConversationKit.log("Missing local speaker ID or remote speaker ID")
			return nil
		}
		return "\(localIdent) -> \(remoteIdent)"
	}
	
	var recordID: CKRecordID? { if let name = self.recordIDName { return CKRecordID(recordName: name) }; return nil }
	
	func delete() {
		guard let recordID = self.recordID else { return }
		
		Cloud.instance.database.deleteRecordWithID(recordID) { recordID, error in
			if error != nil { ConversationKit.log("Failed to delete pending message", error: error) }
		}
	}
	
	func saveToCloud() {
		guard let recordID = self.recordID, local = Speaker.localSpeaker else { return }
		
		Cloud.instance.database.fetchRecordWithID(recordID) { existing, error in
			if let record = existing {
				if (record["lastPendingAt"] != nil && self.pendingAt != nil) || (record["lastPendingAt"] == nil && self.pendingAt == nil) { return }
				record["lastPendingAt"] = self.pendingAt
				Cloud.instance.database.saveRecord(record, completionHandler: { record, error in
					if error != nil { ConversationKit.log("Failed to save pending message", error: error) }
				})
			} else {		//create it
				let record = CKRecord(recordType: PendingMessage.recordName, recordID: recordID)
				record["recipient"] = self.speaker.identifier
				record["speaker"] = local.identifier
				record["lastPendingAt"] = self.pendingAt
				Cloud.instance.database.saveRecord(record, completionHandler: { record, error in
					if error != nil { ConversationKit.log("Failed to save pending message", error: error) }
				})
			}
		}
	}
}

extension Conversation {
	public var hasPendingOutgoingMessage: Bool {
			set {
				if let pending = self.nonLocalSpeaker.pending {
					if pending.pendingAt == nil && !newValue || pending.pendingAt != nil && newValue { return }
					pending.pendingAt = newValue ? NSDate() : nil
					pending.saveToCloud()
				} else if newValue {
					self.nonLocalSpeaker.pending = PendingMessage(speaker: self.nonLocalSpeaker, cachedPendingAt: NSDate())
					self.nonLocalSpeaker.pending?.saveToCloud()
				}
			}

			get {
				return self.nonLocalSpeaker.pending?.pendingAt != nil
			}
		}
	
}