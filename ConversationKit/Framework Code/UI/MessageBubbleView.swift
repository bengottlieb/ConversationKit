//
//  MessageBubbleView.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/23/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

class MessageBubbleView: UIView {
	var text: String = ""
	var rigthHandStem = true
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		self.backgroundColor = UIColor.clearColor()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.backgroundColor = UIColor.clearColor()
	}

	override func drawRect(rect: CGRect) {
		let bounds = self.bounds
		let bezier = UIBezierPath()
		
		if self.rigthHandStem {
			let x1 = bounds.width * 0.05
			let x2 = bounds.width * 0.15
			let x3 = bounds.width * 0.75
			let x4 = bounds.width * 0.92
			let x5 = bounds.width * 0.95
			
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
		}
		
		UIColor.blueColor().setStroke()
		UIColor.greenColor().setFill()
		bezier.fill()
		bezier.stroke()
	}
}
