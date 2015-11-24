//
//  MessageBubbleView.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/23/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

public class MessageBubbleView: UIView {
	public var rightHandStem = false
	public static var messageFont = UIFont.systemFontOfSize(15.0)
	public static var messageBackgroundColor = UIColor.greenColor()
	public static var messageBorderColor = UIColor.blackColor()
	public static var messageTextColor = UIColor.blackColor()
	

	var text: String = ""
	var label: UILabel!
	
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
	
	static let horizontalInset: CGFloat = 20.0
	static let verticalInset: CGFloat = 4.0
	static let stemWidth: CGFloat = 15.0
	
	class func heightForMessage(message: Message, inTableWidth width: CGFloat) -> CGFloat {
		let contentWidth = width - (self.horizontalInset * 2 + self.stemWidth)
		let attr = NSAttributedString(string: message.content, attributes: [NSFontAttributeName: MessageBubbleView.messageFont])
		let bounding = attr.boundingRectWithSize(CGSize(width: contentWidth, height: 10000.0), options: [.UsesLineFragmentOrigin, .UsesFontLeading, .TruncatesLastVisibleLine], context: nil)
		
		return ceil(bounding.height + self.verticalInset * 2)
	}
	
	var labelFrame: CGRect?
	var fullLabelFrame: CGRect {
		var frame = self.bounds.insetBy(dx: MessageBubbleView.horizontalInset, dy: MessageBubbleView.verticalInset)
		if !self.rightHandStem {
			frame.origin.x += MessageBubbleView.stemWidth
		}
		frame.size.width -= MessageBubbleView.stemWidth
		return frame
	}
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		
		if self.label == nil {
			self.label = UILabel(frame: self.fullLabelFrame)
			self.label.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
			self.label.numberOfLines = 0
			self.label.textColor = MessageBubbleView.messageTextColor
			self.label.font = MessageBubbleView.messageFont
			self.label.lineBreakMode = .ByWordWrapping
			self.addSubview(self.label)
			self.label.backgroundColor = UIColor.clearColor()
			self.updateUI()
		} else {
			self.label.frame = self.labelFrame ?? self.fullLabelFrame
		}
	}
	
	func updateUI() {
		if let message = self.message {
			self.rightHandStem = message.speaker.isLocalSpeaker
			self.label?.text = message.content
			self.label?.textAlignment = self.rightHandStem ? .Right : .Left
			let full = self.fullLabelFrame
			if let size = self.label?.sizeThatFits(full.size) {
				self.labelFrame = self.rightHandStem ? CGRect(x: full.maxX - size.width, y: full.origin.y, width: size.width, height: size.height) : CGRect(x: full.origin.x, y: full.origin.y, width: size.width, height: size.height)
			}
			self.setNeedsDisplay()
			self.setNeedsLayout()
		}
	}

	public override func drawRect(rect: CGRect) {
		let labelFrame = self.labelFrame ?? self.fullLabelFrame
		let bubbleWidth = labelFrame.width + MessageBubbleView.horizontalInset * 2 + MessageBubbleView.stemWidth
		let bounds: CGRect
		let bezier = UIBezierPath()
		
		if self.rightHandStem {
			bounds = CGRect(x: self.bounds.width - bubbleWidth, y: 0, width: bubbleWidth, height: self.bounds.height)
			let x1 = bounds.width * 0.05 + bounds.origin.x
			let x2 = bounds.width * 0.15 + bounds.origin.x
			let x3 = bounds.width * 0.75 + bounds.origin.x
			let x4 = bounds.width * 0.92 + bounds.origin.x
			let x5 = bounds.width * 0.95 + bounds.origin.x
			
			let y1 = bounds.height * 0.05
			let y2 = bounds.height * 0.15
			let y3 = bounds.height * 0.15
			let y4 = bounds.height * 0.85
			let y5 = bounds.height * 0.95
			
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
			bounds = CGRect(x: 0, y: 0, width: bubbleWidth, height: self.bounds.height)

			let x1 = bounds.width * 0.05 + bounds.origin.x
			let x2 = bounds.width * 0.08 + bounds.origin.x
			let x3 = bounds.width * 0.25 + bounds.origin.x
			let x4 = bounds.width * 0.85 + bounds.origin.x
			let x5 = bounds.width * 0.95 + bounds.origin.x
			
			let y1 = bounds.height * 0.05
			let y2 = bounds.height * 0.15
			let y3 = bounds.height * 0.15
			let y4 = bounds.height * 0.85
			let y5 = bounds.height * 0.95
			
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
		
		MessageBubbleView.messageBackgroundColor.setFill()
		MessageBubbleView.messageBorderColor.setStroke()
		bezier.fill()
		bezier.stroke()
	}
}
