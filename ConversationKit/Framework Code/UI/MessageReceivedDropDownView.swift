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

public class MessageReceivedDropDownView: UIViewController, MessageReceivedDisplay, UIScrollViewDelegate {
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
		let maxWidth: CGFloat = 375.0
		let height: CGFloat = 44
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
		
		self.hideTimer = NSTimer.scheduledTimerWithTimeInterval(10.0, target: self, selector: "autoHide", userInfo: nil, repeats: false)
		scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
	}
	
	func autoHide() {
		self.hide(true)
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
	
}


extension MessageReceivedDropDownView {
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