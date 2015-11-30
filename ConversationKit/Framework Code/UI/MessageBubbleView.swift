//
//  MessageBubbleView.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/23/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

public class MessageBubbleView: UIView {
	public static var showAvatarImage = true
	public static var roundAvatarImages = true
	public static var avatarImageSize = CGSize(width: 50, height: 50)
	public static var messageFont = UIFont.systemFontOfSize(15.0)
	public static var localMessageBackgroundColor = UIColor.greenColor()
	public static var localMessageBorderColor = UIColor.blackColor()
	public static var localMessageTextColor = UIColor.blackColor()

	public static var otherMessageBackgroundColor = UIColor.blueColor()
	public static var otherMessageBorderColor = UIColor.blackColor()
	public static var otherMessageTextColor = UIColor.whiteColor()

	public static var avatarImagePlaceholder: UIImage?

	public var rightHandStem = false

	static var defaultImagePlaceholder: UIImage = {
		let path = NSBundle(forClass: MessageBubbleView.self).pathForResource("speaker_placeholder", ofType: "png")
		return UIImage(contentsOfFile: path!)!
	}()
	
	var text: String = ""
	var label: UILabel!
	var imageView: UIImageView!
	
	public var message: Message? { didSet {
		self.updateUI()
	}}
	
	public override init(frame: CGRect) {
		super.init(frame: frame)
		self.backgroundColor = UIColor.clearColor()
	}

	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.backgroundColor = UIColor.clearColor()
	}
	
	static let horizontalInset: CGFloat = 10.0
	static let verticalInset: CGFloat = 7.0
	static let stemWidth: CGFloat = 11.0
	
	class func heightForMessage(message: Message, inTableWidth width: CGFloat) -> CGFloat {
		var contentWidth = width - (self.horizontalInset * 2 + self.stemWidth)
		if MessageBubbleView.showAvatarImage { contentWidth -= MessageBubbleView.avatarImageSize.width }
		let attr = NSAttributedString(string: message.content, attributes: [NSFontAttributeName: MessageBubbleView.messageFont])
		let bounding = attr.boundingRectWithSize(CGSize(width: contentWidth, height: 10000.0), options: [.UsesLineFragmentOrigin, .UsesFontLeading, .TruncatesLastVisibleLine], context: nil)
		
		let height = ceil(bounding.height + self.verticalInset * 2)
		if MessageBubbleView.showAvatarImage && height < MessageBubbleView.avatarImageSize.height { return MessageBubbleView.avatarImageSize.height }
		return height
	}
	
	var labelFrame: CGRect?
	var fullLabelFrame: CGRect {
		let avatarWidth: CGFloat = MessageBubbleView.showAvatarImage ? MessageBubbleView.avatarImageSize.width : 0
		var frame = self.bounds.insetBy(dx: MessageBubbleView.horizontalInset, dy: MessageBubbleView.verticalInset)
		if !self.rightHandStem {
			frame.origin.x += MessageBubbleView.stemWidth + avatarWidth
		}
		frame.size.width -= MessageBubbleView.stemWidth + avatarWidth
		return frame
	}
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		
		var needsUpdate = false
		if self.label == nil {
			self.label = UILabel(frame: self.fullLabelFrame)
			self.label.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
			self.label.numberOfLines = 0
			self.label.font = MessageBubbleView.messageFont
			self.label.lineBreakMode = .ByWordWrapping
			self.addSubview(self.label)
			self.label.backgroundColor = UIColor.clearColor()
			needsUpdate = true
		} else {
			self.label.frame = self.labelFrame ?? self.fullLabelFrame
		}

		if MessageBubbleView.showAvatarImage && self.imageView == nil {
			self.imageView = UIImageView(frame: self.imageFrame)
			self.imageView.contentMode = .ScaleAspectFill
			self.imageView.clipsToBounds = true
			if MessageBubbleView.roundAvatarImages {
				self.imageView.layer.cornerRadius = MessageBubbleView.avatarImageSize.width / 2.0
				self.imageView.layer.masksToBounds = true
			}
			self.addSubview(self.imageView)
			needsUpdate = true
		} else {
			self.imageView?.frame = self.imageFrame
		}
		
		if needsUpdate { self.updateUI() }
	}
	
	var imageFrame: CGRect {
		if self.rightHandStem {
			return CGRect(x: self.bounds.width - MessageBubbleView.avatarImageSize.width, y: 0, width: MessageBubbleView.avatarImageSize.width, height: MessageBubbleView.avatarImageSize.height)
		}
		return CGRect(x: 0, y: 0, width: MessageBubbleView.avatarImageSize.width, height: MessageBubbleView.avatarImageSize.height)
	}
	
	func updateUI() {
		if let message = self.message {
			self.setNeedsDisplay()
			self.setNeedsLayout()
			self.label?.textColor = message.speaker.isLocalSpeaker ? MessageBubbleView.localMessageTextColor : MessageBubbleView.otherMessageTextColor

			self.rightHandStem = message.speaker.isLocalSpeaker
			self.label?.text = message.content
			self.label?.textAlignment = self.rightHandStem ? .Right : .Left
			let full = self.fullLabelFrame
			if let size = self.label?.sizeThatFits(full.size) {
				self.labelFrame = self.rightHandStem ? CGRect(x: full.maxX - size.width, y: full.origin.y, width: size.width, height: size.height) : CGRect(x: full.origin.x, y: full.origin.y, width: size.width, height: size.height)
			}
			self.imageView?.image = self.message?.speaker?.avatarImage ?? MessageBubbleView.avatarImagePlaceholder ?? MessageBubbleView.defaultImagePlaceholder
		}
	}

	public override func drawRect(rect: CGRect) {
		let labelFrame = self.labelFrame ?? self.fullLabelFrame
		let bubbleHeight = labelFrame.height + MessageBubbleView.verticalInset * 2
		let bubbleWidth = labelFrame.width + MessageBubbleView.horizontalInset * 2 + MessageBubbleView.stemWidth
		let bounds: CGRect
		let bezier = UIBezierPath()
		let avatarWidth: CGFloat = MessageBubbleView.showAvatarImage ? MessageBubbleView.avatarImageSize.width : 0
		
		let horizontalMargin: CGFloat = 5.0
		let verticalMargin: CGFloat = 5.0
		let cornerRadius: CGFloat = 10.0
		let stemWidth: CGFloat = 5.0
		
		if self.rightHandStem {
			bounds = CGRect(x: self.bounds.width - (bubbleWidth + avatarWidth), y: 0, width: bubbleWidth, height: bubbleHeight)
			let x1 = horizontalMargin + bounds.origin.x
			let x2 = horizontalMargin + cornerRadius + bounds.origin.x
			let x3 = bounds.origin.x + bounds.width - (horizontalMargin + cornerRadius + stemWidth)
			let x4 = bounds.origin.x + bounds.width - (horizontalMargin + stemWidth)
			let x5 = bounds.origin.x + bounds.width - (horizontalMargin)
			
			let y1 = verticalMargin
			let y2 = verticalMargin + cornerRadius
			let y3 = verticalMargin + cornerRadius
			let y4 = bounds.height - (verticalMargin + cornerRadius)
			let y5 = bounds.height - (verticalMargin)
			
			let a = CGPoint(x: x3, y: y5)
			let b = CGPoint(x: x4, y: y4)
			let c = CGPoint(x: x5, y: y5)
			let d = CGPoint(x: x4, y: y3)
			let e = CGPoint(x: x4, y: y2)
			let f = CGPoint(x: x3, y: y1)
			let g = CGPoint(x: x2, y: y1)
			let h = CGPoint(x: x1, y: y2)
			let i = CGPoint(x: x1, y: y4)
			let j = CGPoint(x: x2, y: y5)
			
			let cpA = CGPoint(x: x4, y: y5)
			let cpC = cpA
			let cpE = CGPoint(x: x4, y: y1)
			let cpG = CGPoint(x: x1, y: y1)
			let cpI = CGPoint(x: x1, y: y5)
			
			
			bezier.moveToPoint(a)
			bezier.addCurveToPoint(b, controlPoint1: cpA, controlPoint2: cpA)
			bezier.addCurveToPoint(c, controlPoint1: cpC, controlPoint2: cpC)
			bezier.addCurveToPoint(d, controlPoint1: cpA, controlPoint2: cpA)
			
			bezier.addLineToPoint(e)
			bezier.addCurveToPoint(f, controlPoint1: cpE, controlPoint2: cpE)
			
			bezier.addLineToPoint(g)
			bezier.addCurveToPoint(h, controlPoint1: cpG, controlPoint2: cpG)
			
			bezier.addLineToPoint(i)
			bezier.addCurveToPoint(j, controlPoint1: cpI, controlPoint2: cpI)
			
			bezier.addLineToPoint(a)
		} else {
			bounds = CGRect(x: avatarWidth, y: 0, width: bubbleWidth, height: bubbleHeight)

			let x1 = bounds.origin.x + horizontalMargin
			let x2 = bounds.origin.x + cornerRadius + horizontalMargin
			let x3 = bounds.origin.x + horizontalMargin + stemWidth + cornerRadius
			let x4 = bounds.origin.x + bounds.width - (horizontalMargin + stemWidth)
			let x5 = bounds.origin.x + bounds.width - (horizontalMargin)
			
			let y1 = verticalMargin
			let y2 = verticalMargin + cornerRadius
			let y3 = verticalMargin + cornerRadius
			let y4 = bounds.height - (verticalMargin + cornerRadius)
			let y5 = bounds.height - (verticalMargin)
			
			let a = CGPoint(x: x3, y: y5)
			let b = CGPoint(x: x2, y: y4)
			let c = CGPoint(x: x1, y: y5)
			let d = CGPoint(x: x2, y: y3)
			let e = CGPoint(x: x2, y: y2)
			let f = CGPoint(x: x3, y: y1)
			let g = CGPoint(x: x4, y: y1)
			let h = CGPoint(x: x5, y: y2)
			let i = CGPoint(x: x5, y: y4)
			let j = CGPoint(x: x4, y: y5)
			
			let cpA = CGPoint(x: x2, y: y5)
			let cpC = cpA
			let cpE = CGPoint(x: x2, y: y1)
			let cpG = CGPoint(x: x5, y: y1)
			let cpI = CGPoint(x: x5, y: y5)
			
			
			bezier.moveToPoint(a)
			bezier.addCurveToPoint(b, controlPoint1: cpA, controlPoint2: cpA)
			bezier.addCurveToPoint(c, controlPoint1: cpC, controlPoint2: cpC)
			bezier.addCurveToPoint(d, controlPoint1: cpA, controlPoint2: cpA)
			
			bezier.addLineToPoint(e)
			bezier.addCurveToPoint(f, controlPoint1: cpE, controlPoint2: cpE)
			
			bezier.addLineToPoint(g)
			bezier.addCurveToPoint(h, controlPoint1: cpG, controlPoint2: cpG)
			
			bezier.addLineToPoint(i)
			bezier.addCurveToPoint(j, controlPoint1: cpI, controlPoint2: cpI)
			
			bezier.addLineToPoint(a)
		}
		
		if let message = self.message {
			(message.speaker.isLocalSpeaker ? MessageBubbleView.localMessageBackgroundColor : MessageBubbleView.otherMessageBackgroundColor).setFill()
			(message.speaker.isLocalSpeaker ? MessageBubbleView.localMessageBorderColor : MessageBubbleView.otherMessageBorderColor).setStroke()
		}
		bezier.fill()
		bezier.stroke()
	}
}
