//
//  ConversationKit.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/14/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class ConversationKit: NSObject {
	public static let instance = ConversationKit()
	
	public struct notifications {
		public static let setupComplete = "ConversationKit.setupComplete"
	}
	
	override init() {
		super.init()
	}
	
	public func setup(containerName: String? = nil, localSpeakerName: String, localSpeakerIdentifier: String, completion: (Bool) -> Void) {
		
		Cloud.instance.setup(containerName) {
			DataStore.instance.importBlock { moc in
				let localSpeaker = moc.localSpeaker
				localSpeaker.name = localSpeakerName
				localSpeaker.identifier = localSpeakerIdentifier
				
				localSpeaker.saveToCloudKit { success in
					Utilities.postNotification(ConversationKit.notifications.setupComplete)
				
					completion(success)
				}
			}
		}
	}
}