//
//  ConversationKitUtilities.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class Utilities {
	public class func postNotification(name: String, object: NSObject? = nil) {
		Utilities.mainThread {
			NSNotificationCenter.defaultCenter().postNotificationName(name, object: object)
		}
	}
	
	public class func mainThread(block: () -> Void) {
		dispatch_async(dispatch_get_main_queue(), block)
	}
}