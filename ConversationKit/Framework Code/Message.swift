//
//  Message.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class Message: NSObject {
	public let conversation: Conversation
	public let content: String
	public let speaker: Speaker
	
	init(conversation convo: Conversation, content msg: String, speaker spkr: Speaker) {
		conversation = convo
		content = msg
		speaker = spkr
		super.init()
	}
}