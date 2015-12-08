//
//  ConversationKit+Display.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 12/4/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import Foundation
import UIKit

extension ConversationKit {
	public class func displayIncomingMessage(message: Message, when: NSDate? = nil) {
		if UIApplication.sharedApplication().applicationState == .Active && when == nil {
			guard let convo = message.conversation else { return }
			guard !self.visibleConversations.contains(convo) else { return }
			
			dispatch_async(ConversationKit.queue) {
				self.pendingMessageDisplays += [message]
				ConversationKit.instance.updateMessageDisplays()
			}
		} else {
			let note = UILocalNotification()
			
			note.alertBody = message.speaker.name == nil ? message.content : "\(message.speaker.name!): \(message.content)"
			note.fireDate = when ?? NSDate(timeIntervalSinceNow: 0.001)
			note.category = ConversationKit.MessageCategory
			note.userInfo = ["speaker": message.conversation?.nonLocalSpeaker.speakerRef ?? ""]
			UIApplication.sharedApplication().scheduleLocalNotification(note)
		}
	}
	
	func updateMessageDisplays() {
		guard self.currentDisplayedMessage == nil else { return }
		guard let message = ConversationKit.pendingMessageDisplays.first else { return }
		
		ConversationKit.pendingMessageDisplays.removeAtIndex(0)
		
		Utilities.mainThread {
			if let root = ConversationKit.messageDisplayWindow?.rootViewController {
				let display = MessageReceivedDropDown(message: message)
				self.currentDisplayedMessage = display
				display.display(root, didHide: { automatically in
					self.currentDisplayedMessage = nil
					dispatch_async(ConversationKit.queue) { self.updateMessageDisplays() }
				})
			}
		}
	}

	static func addVisibleConversation(convo: Conversation) { dispatch_async(ConversationKit.queue) { self.visibleConversations.insert(convo) } }
	static func removeVisibleConversation(convo: Conversation) { dispatch_async(ConversationKit.queue) { self.visibleConversations.remove(convo) } }
	
}