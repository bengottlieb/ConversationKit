//
//  ConversationKitUtilities.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CommonCrypto

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

extension NSData {
	var sha255Hash: String {
		let shaOut: NSMutableData! = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH));
		CC_SHA256(self.bytes, CC_LONG(self.length), UnsafeMutablePointer<UInt8>(shaOut.mutableBytes));
		
		var string = ""
		var byteArray = [UInt8](count: shaOut.length, repeatedValue: 0x0)
		
		shaOut.getBytes(&byteArray, length: shaOut.length)
		
		
		for i in 0..<shaOut.length {
			let byte = Int(byteArray[i])
			let chunk = String(format: "%02x", byte)
			string += chunk
		}
		
		return string;
	}

}