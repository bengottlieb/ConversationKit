//
//  Message.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

class Message: NSObject {
	let conversation: Conversation
	let content: String
	let speaker: Speaker
	
	init(conversation convo: Conversation, content msg: String, speaker spkr: Speaker) {
		conversation = convo
		content = msg
		speaker = spkr
		super.init()
	}
}