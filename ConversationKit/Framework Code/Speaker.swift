//
//  Speaker.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class Speaker: NSObject {
	public static var localSpeaker = Speaker(identifier: nil)
	
	public let identifier: String?
	
	public init(identifier id: String?) {
		identifier = id
		super.init()
	}
}