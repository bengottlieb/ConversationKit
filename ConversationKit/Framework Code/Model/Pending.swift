//
//  PendingMessage.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/30/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import Foundation
import CloudKit

class PendingMessage {
	static var recordName = "ConversationKitPending"
	
	let speaker: Speaker!
	var pendingAt: Date?
	
	init?(speaker who: Speaker, cachedPendingAt: Date?) {
		speaker = who
		pendingAt = cachedPendingAt
		if speaker == nil { return nil }
	}
	
	init(speaker who: Speaker) {
		speaker = who
		pendingAt = Date()
		
		self.saveToCloud()
	}
	
	var recordIDName: String? {
		guard let local = Speaker.localSpeaker, let localIdent = local.identifier, let remoteIdent = self.speaker.identifier else {
			ConversationKit.log("Missing local speaker ID or remote speaker ID")
			return nil
		}
		return "\(localIdent) -> \(remoteIdent)"
	}
	
	var recordID: CKRecordID? { if let name = self.recordIDName { return CKRecordID(recordName: name) }; return nil }
	
	func delete() {
		guard let recordID = self.recordID else { return }
		
		Cloud.instance.database.delete(withRecordID: recordID) { recordID, error in
			if error != nil { ConversationKit.log("Failed to delete pending message", error: error) }
		}
	}
	
	struct keys {
		static let lastPendingAt = "lastPendingAt"
		static let recipient = "recipient"
		static let speaker = "speaker"
	}

	func saveToCloud() {
		guard let recordID = self.recordID, let local = Speaker.localSpeaker else { return }
		
		Cloud.instance.database.fetch(withRecordID: recordID) { existing, error in
			if let record = existing {
				if (record[keys.lastPendingAt] != nil && self.pendingAt != nil) || (record[keys.lastPendingAt] == nil && self.pendingAt == nil) { return }
				record[keys.lastPendingAt] = self.pendingAt as CKRecordValue?
				Cloud.instance.database.save(record, completionHandler: { record, error in
					if error != nil { ConversationKit.log("Failed to save pending message", error: error) }
				})
			} else {		//create it
				let record = CKRecord(recordType: PendingMessage.recordName, recordID: recordID)
				record[keys.recipient] = self.speaker.identifier as CKRecordValue?
				record[keys.speaker] = local.identifier as CKRecordValue?
				record[keys.lastPendingAt] = self.pendingAt as CKRecordValue?
				Cloud.instance.database.save(record, completionHandler: { record, error in
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
					pending.pendingAt = newValue ? Date() : nil
					pending.saveToCloud()
				} else if newValue {
					self.nonLocalSpeaker.pending = PendingMessage(speaker: self.nonLocalSpeaker, cachedPendingAt: Date())
					self.nonLocalSpeaker.pending?.saveToCloud()
				}
			}

			get {
				return self.nonLocalSpeaker.pending?.pendingAt != nil
			}
		}
	
}
