//
//  Router.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/17/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import Foundation
import CloudKit

class Router: NSObject {
	static let instance = Router()
	
	var pendingMessages: Set<CKRecord> = []

	func importMessage(record: CKRecord) {
		if record["speaker"] is CKReference && record["listener"] is CKReference {
			if !self.routeMessage(record) {
				dispatch_async(ConversationKit.instance.queue) { self.pendingMessages.insert(record) }
			}
		} else {		//messages must have both a speaker and a listener
			Cloud.instance.database.deleteRecordWithID(record.recordID) { recordID, error in
				
			}
		}
	}
	
	func routeMessage(record: CKRecord) -> Bool {
		guard let speakerRef = record["speaker"] as? CKReference, listenerRef = record["listener"] as? CKReference else { return false }
		guard let speaker = Speaker.speakerFromRecordID(speakerRef.recordID), let listener = Speaker.speakerFromRecordID(listenerRef.recordID) else { return false }
			
		let message = Message()
		message.speaker = speaker
		message.listener = listener
		message.spokenAt = record["spokenAt"] as? NSDate ?? NSDate()
		message.cloudKitRecordID = record.recordID
		message.saveManagedObject(nil)
		
		Conversation.conversationWithSpeaker(speaker, listener: listener).addMessage(message)
		return true
	}
	
	func routePendingMessages() {
		dispatch_async(ConversationKit.instance.queue) {
			let pending = self.pendingMessages
			
			for record in pending {
				if self.routeMessage(record) {
					self.pendingMessages.remove(record)
				}
			}
		}
	}
}