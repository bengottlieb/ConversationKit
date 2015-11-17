//
//  Conversation.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public class Conversation: NSObject {
	var existingConversations: [Conversation] = []
	
	var startedBy: Speaker
	var joinedBy: Speaker

	
	init(starter: Speaker, and other: Speaker) {
		startedBy = starter
		joinedBy = other
		super.init()
	}
	
}