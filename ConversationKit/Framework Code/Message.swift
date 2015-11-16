//
//  Message.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CoreData

public class Message: NSManagedObject {
	@NSManaged public var conversation: Conversation
	@NSManaged public var content: String
	@NSManaged public var speaker: Speaker
	
}