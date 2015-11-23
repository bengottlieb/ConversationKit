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
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    

	var message: Message? { didSet {
		self.messageContentLabel?.text = self.message?.content
		self.messageSpeakerLabel?.text = self.message?.speaker.name
		
		if self.message?.speaker.isLocalSpeaker ?? false {
			self.messageContentLabel?.textAlignment = .Right
			self.messageSpeakerLabel?.textAlignment = .Right
		} else {
			self.messageContentLabel?.textAlignment = .Left
			self.messageSpeakerLabel?.textAlignment = .Left
		}
		}}
}
