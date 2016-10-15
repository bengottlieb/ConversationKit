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
	public class func displayIncomingMessage(_ message: Message, when: Date? = nil) {
		if UIApplication.shared.applicationState == .active && when == nil {
			guard let convo = message.conversation else { return }
			guard !self.visibleConversations.contains(convo) else { return }
			
			ConversationKit.queue.async {
				self.pendingMessageDisplays += [message]
				ConversationKit.instance.updateMessageDisplays()
			}
		} else {
			let note = UILocalNotification()
			
			note.alertBody = message.speaker.name == nil ? message.content : "\(message.speaker.name!): \(message.content)"
			note.fireDate = when ?? Date(timeIntervalSinceNow: 0.001)
			note.category = ConversationKit.MessageCategory
			note.userInfo = ["speaker": message.conversation?.nonLocalSpeaker.speakerRef ?? ""]
			UIApplication.shared.scheduleLocalNotification(note)
		}
	}
	
	func updateMessageDisplays() {
		guard self.currentDisplayedMessage == nil else { return }
		guard let message = ConversationKit.pendingMessageDisplays.first else { return }
		
		ConversationKit.pendingMessageDisplays.remove(at: 0)
		
		Utilities.mainThread {
			if let root = ConversationKit.messageDisplayWindow?.rootViewController {
				let display = MessageReceivedDropDown(message: message)
				self.currentDisplayedMessage = display
				display.display(viewController: root, didHide: { automatically in
					self.currentDisplayedMessage = nil
					ConversationKit.queue.async { self.updateMessageDisplays() }
				})
			}
		}
	}

	static func addVisibleConversation(_ convo: Conversation) { ConversationKit.queue.async { self.visibleConversations.insert(convo) } }
	static func removeVisibleConversation(_ convo: Conversation) { ConversationKit.queue.async { self.visibleConversations.remove(convo) } }
	
}
