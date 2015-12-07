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
	func hide(automatically: Bool)
}

public class MessageReceivedDropDown: UIViewController, MessageReceivedDisplay, UIScrollViewDelegate {
	public var message: Message!
	public var contentLabel: UILabel!
	public var mainButton: UIButton!
	public var senderLabel: UILabel!
	public var imageView: UIImageView!
	public var didHide: ((Bool) -> Void)!
	public weak var hideTimer: NSTimer?
	public var contentView: UIView!
	
	var scrollView: UIScrollView? { return self.view as? UIScrollView }
	
	public convenience required init(message: Message) {
		self.init()
		self.message = message
		self.automaticallyAdjustsScrollViewInsets = false
		self.edgesForExtendedLayout = .None
	}
	
	public override func loadView() {
		self.view = UIScrollView(frame: CGRectZero)
		self.scrollView?.showsHorizontalScrollIndicator = false
		self.scrollView?.showsVerticalScrollIndicator = false
		self.scrollView?.delegate = self
		self.scrollView?.pagingEnabled = true
	}
	
	public func display(viewController: UIViewController, didHide: (Bool) -> Void) {
		guard let scrollView = self.scrollView else { didHide(true); return }
		
		let parentBounds = viewController.view.bounds
		let maxWidth: CGFloat = 500.0
		let height: CGFloat = 64
		let left: CGFloat = max(0, (parentBounds.width - maxWidth) / 2)
		let width = min(maxWidth, parentBounds.width)
		
		scrollView.frame = CGRect(x: left, y: 0, width: width, height: height)
		scrollView.contentSize = CGSize(width: width, height: height * 2)
		
		self.contentView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
		self.view.backgroundColor = UIColor.clearColor()
		scrollView.addSubview(self.contentView)
		self.didHide = didHide
		scrollView.contentOffset = CGPoint(x: 0, y: height)
		
		self.willMoveToParentViewController(viewController)
		viewController.addChildViewController(self)
		viewController.view.addSubview(self.view)
		self.didMoveToParentViewController(viewController)
		
		let duration = ConversationKit.feedbackLevel == .Production ? 7.0 : 3.0
		self.hideTimer = NSTimer.scheduledTimerWithTimeInterval(duration, target: self, selector: "autoHide", userInfo: nil, repeats: false)
		scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
	}
	
	func autoHide() {
		self.hide(true)
	}
	
	var textColor = UIColor.whiteColor()
	let contentFont = UIFont.systemFontOfSize(16)
	let senderFont = UIFont.boldSystemFontOfSize(16)
	
	public override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		let bounds = self.contentView.bounds
		let imageViewWidth: CGFloat = 44
		let hMargin: CGFloat = 5
		let vMargin: CGFloat = 5
		
		self.contentView.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
		
		if self.mainButton == nil {
			self.mainButton = UIButton(type: .Custom)
			self.mainButton.frame = self.contentView.bounds
			self.contentView.addSubview(self.mainButton)
			self.mainButton.showsTouchWhenHighlighted = true
			self.mainButton.addTarget(self, action: "mainButtonTapped:", forControlEvents: .TouchUpInside)
		}
		
		if self.contentLabel == nil {
			self.contentLabel = UILabel(frame: CGRect(x: imageViewWidth + hMargin, y: vMargin, width: bounds.width - (imageViewWidth + hMargin * 2), height: bounds.height - vMargin * 2))
			self.contentLabel.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
			self.view.addSubview(self.contentLabel)
			self.contentLabel.textColor = UIColor.whiteColor()
			self.contentLabel.numberOfLines = 0
			self.contentLabel.lineBreakMode = .ByWordWrapping
		}
		
		if let message = self.message {
			let speakerAttr = [ NSFontAttributeName: self.senderFont, NSForegroundColorAttributeName: self.textColor.colorWithAlphaComponent(0.75) ]
			let contentAttr = [ NSFontAttributeName: self.contentFont, NSForegroundColorAttributeName: self.textColor ]
			let string = NSMutableAttributedString(string: (message.speaker?.name ?? "") + "\n", attributes: speakerAttr)
			string.appendAttributedString(NSAttributedString(string: message.content ?? "", attributes: contentAttr))
			self.contentLabel.attributedText = string
		}
	}
	
	public func hide(automatically: Bool) {
		UIView.animateWithDuration(0.25, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5, options: [], animations: {
			self.view.transform = CGAffineTransformMakeTranslation(0, -self.view.bounds.height)
		}, completion: { completed in
			self.willMoveToParentViewController(nil)
			self.view.removeFromSuperview()
			self.removeFromParentViewController()
			self.didMoveToParentViewController(nil)
			self.didHide?(automatically)
		})
	}
	
	func mainButtonTapped(sender: UIButton?) {
		if let convo = self.message.conversation {
			Utilities.postNotification(ConversationKit.notifications.conversationSelected, object: convo)
		}
	}
}


extension MessageReceivedDropDown {
	public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
		self.checkForHidden()
	}
	
	public func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
		self.checkForHidden()
	}
	
	public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		self.checkForHidden()
	}
	
	func checkForHidden() {
		if let sv = self.scrollView where sv.contentOffset.y >= sv.bounds.height {
			self.hide(false)
		}
	}
	
	
}