//
//  ConversationKitUtilities.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CommonCrypto

open class Utilities {
	open class func postNotification(_ note: Notification.Name, object: NSObject? = nil) {
		Utilities.mainThread {
			NotificationCenter.default.post(name: note, object: object)
		}
	}
	
	open class func mainThread(_ block: @escaping () -> Void) {
		DispatchQueue.main.async(execute: block)
	}
}

extension Data {
	var sha255Hash: String {
		var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
		self.withUnsafeBytes {
			_ = CC_SHA256($0, CC_LONG(self.count), &hash)
		}
		
		var string = ""
		
		for i in 0..<hash.count {
			let byte = Int(hash[i])
			let chunk = String(format: "%02x", byte)
			string += chunk
		}
		
		return string;
	}

}

public let kConversationKitErrorDomain = "ConversationKitError"

extension NSError {
	
	@objc public enum ConversationKitError: Int { case cloudSaveNotAllowed }
	
	convenience init(conversationKitError: ConversationKitError) {
		self.init(domain: kConversationKitErrorDomain, code: conversationKitError.rawValue, userInfo: [NSLocalizedDescriptionKey: "\(conversationKitError)"])
	}
}
