//
//  MessageReceivedDropDownView.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 12/3/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit

@objc public protocol MessageReceivedDisplay {
	init(message: Message)
	var message: Message! { get set }
	func display(viewController: UIViewController, didHide: (Bool) -> Void)
	func hide()
}

public class MessageReceivedDropDownView: UIViewController, MessageReceivedDisplay {
	public var message: Message!
	public var contentLabel: UILabel!
	public var senderLabel: UILabel!
	public var imageView: UIImageView!
	public var didHide: ((Bool) -> Void)!
	public weak var hideTimer: NSTimer?
	public var contentView: UIView!
	
	var scrollView: UIScrollView? { return self.view as? UIScrollView }
	
	public convenience required init(message: Message) {
		self.init()
		self.message = message
	}
	
	public override func loadView() {
		self.view = UIScrollView(frame: CGRectZero)
	}
	
	
	
	public func display(viewController: UIViewController, didHide: (Bool) -> Void) {
		guard let scrollView = self.scrollView else { didHide(true); return }
		
		let parentBounds = viewController.view.bounds
		let maxWidth: CGFloat = 320
		let height: CGFloat = 44
		let left: CGFloat = max(0, (parentBounds.width - maxWidth) / 2)
		
		scrollView.frame = CGRect(x: left, y: 0, width: min(maxWidth, parentBounds.width), height: height * 2)
		
		self.contentView = UIView(frame: CGRect(x: 0, y: 0, width: scrollView.bounds.width, height: height))
		self.view.backgroundColor = UIColor(white: 0.1, alpha: 0.5)
		scrollView.addSubview(self.contentView)
		self.didHide = didHide
		
		self.willMoveToParentViewController(viewController)
		viewController.addChildViewController(self)
		viewController.view.addSubview(self.view)
		self.didMoveToParentViewController(viewController)
		
		self.hideTimer = NSTimer.scheduledTimerWithTimeInterval(10.0, target: self, selector: "autoHide", userInfo: nil, repeats: false)
		scrollView.setContentOffset(CGPoint(x: 0, y: height), animated: true)
	}
	
	func autoHide() {
		self.hide()
	}
	
	public override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		let bounds = self.contentView.bounds
		let imageViewWidth: CGFloat = 44
		let hMargin: CGFloat = 5
		let vMargin: CGFloat = 5
		
		self.contentView.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
		
		if self.contentLabel == nil {
			self.contentLabel = UILabel(frame: CGRect(x: imageViewWidth + hMargin, y: vMargin, width: bounds.width - (imageViewWidth + hMargin * 2), height: bounds.height - vMargin * 2))
			self.contentLabel.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
			self.view.addSubview(self.contentLabel)
			self.contentLabel.textColor = UIColor.whiteColor()
			self.contentLabel.numberOfLines = 0
			self.contentLabel.lineBreakMode = .ByWordWrapping
		}
		
		self.contentLabel.text = self.message?.content
	}
	
	public func hide() {
		UIView.animateWithDuration(0.25, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5, options: [], animations: {
			self.view.transform = CGAffineTransformMakeTranslation(0, -self.view.bounds.height)
		}, completion: { completed in
			self.willMoveToParentViewController(nil)
			self.view.removeFromSuperview()
			self.removeFromParentViewController()
			self.didMoveToParentViewController(nil)
			self.didHide?(false)
		})
	}
	
}
