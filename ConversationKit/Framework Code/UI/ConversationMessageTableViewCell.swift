//
//  ConversationMessageTableViewCell.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/23/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

class ConversationMessageTableViewCell: UITableViewCell {
	static let identifier = "ConversationMessageTableViewCell"
	
	@IBOutlet var messageContentLabel: UILabel!
	@IBOutlet var messageSpeakerLabel: UILabel!
	@IBOutlet var bubbleView: MessageBubbleView!
	
    override func awakeFromNib() {
        super.awakeFromNib()
		self.selectionStyle = .None
    }

	var message: Message? { didSet {
		self.bubbleView.message = self.message
	}}
	
	class func heightForMessage(message: Message, inTableWidth width: CGFloat) -> CGFloat {
		return MessageBubbleView.heightForMessage(message, inTableWidth: width - 16) + 16.0
	}
}
