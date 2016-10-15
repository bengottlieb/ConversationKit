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
	func display(viewController: UIViewController, didHide: @escaping (Bool) -> Void)
	func hide(automatically: Bool)
}

open class MessageReceivedDropDown: UIViewController, MessageReceivedDisplay, UIScrollViewDelegate {
	open var message: Message!
	open var contentLabel: UILabel!
	open var mainButton: UIButton!
	open var senderLabel: UILabel!
	open var imageView: UIImageView!
	open var didHide: ((Bool) -> Void)!
	open weak var hideTimer: Timer?
	open var contentView: UIView!
	
	var scrollView: UIScrollView? { return self.view as? UIScrollView }
	
	public convenience required init(message: Message) {
		self.init()
		self.message = message
		self.automaticallyAdjustsScrollViewInsets = false
		self.edgesForExtendedLayout = UIRectEdge()
	}
	
	open override func loadView() {
		self.view = UIScrollView(frame: CGRect.zero)
		self.scrollView?.showsHorizontalScrollIndicator = false
		self.scrollView?.showsVerticalScrollIndicator = false
		self.scrollView?.delegate = self
		self.scrollView?.isPagingEnabled = true
	}
	
	open func display(viewController: UIViewController, didHide: @escaping (Bool) -> Void) {
		guard let scrollView = self.scrollView else { didHide(true); return }
		
		let parentBounds = viewController.view.bounds
		let maxWidth: CGFloat = 500.0
		let height: CGFloat = 64
		let left: CGFloat = max(0, (parentBounds.width - maxWidth) / 2)
		let width = min(maxWidth, parentBounds.width)
		
		scrollView.frame = CGRect(x: left, y: 0, width: width, height: height)
		scrollView.contentSize = CGSize(width: width, height: height * 2)
		
		self.contentView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
		self.view.backgroundColor = UIColor.clear
		scrollView.addSubview(self.contentView)
		self.didHide = didHide
		scrollView.contentOffset = CGPoint(x: 0, y: height)
		
		self.willMove(toParentViewController: viewController)
		viewController.addChildViewController(self)
		viewController.view.addSubview(self.view)
		self.didMove(toParentViewController: viewController)
		
		let duration = ConversationKit.feedbackLevel == .production ? 7.0 : 3.0
		self.hideTimer = Timer.scheduledTimer(timeInterval: duration, target: self, selector: #selector(autoHide), userInfo: nil, repeats: false)
		scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
	}
	
	func autoHide() {
		self.hide(automatically: true)
	}
	
	var textColor = UIColor.white
	let contentFont = UIFont.systemFont(ofSize: 16)
	let senderFont = UIFont.boldSystemFont(ofSize: 16)
	
	open override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		let bounds = self.contentView.bounds
		let imageViewWidth: CGFloat = 44
		let hMargin: CGFloat = 5
		let vMargin: CGFloat = 5
		
		self.contentView.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
		
		if self.mainButton == nil {
			self.mainButton = UIButton(type: .custom)
			self.mainButton.frame = self.contentView.bounds
			self.contentView.addSubview(self.mainButton)
			self.mainButton.showsTouchWhenHighlighted = true
			self.mainButton.addTarget(self, action: #selector(MessageReceivedDropDown.mainButtonTapped(_:)), for: .touchUpInside)
		}
		
		if self.contentLabel == nil {
			self.contentLabel = UILabel(frame: CGRect(x: imageViewWidth + hMargin, y: vMargin, width: bounds.width - (imageViewWidth + hMargin * 2), height: bounds.height - vMargin * 2))
			self.contentLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			self.view.addSubview(self.contentLabel)
			self.contentLabel.textColor = UIColor.white
			self.contentLabel.numberOfLines = 0
			self.contentLabel.lineBreakMode = .byWordWrapping
		}
		
		if let message = self.message {
			let speakerAttr = [ NSFontAttributeName: self.senderFont, NSForegroundColorAttributeName: self.textColor.withAlphaComponent(0.75) ]
			let contentAttr = [ NSFontAttributeName: self.contentFont, NSForegroundColorAttributeName: self.textColor ] as [String : Any]
			let string = NSMutableAttributedString(string: (message.speaker?.name ?? "") + "\n", attributes: speakerAttr)
			string.append(NSAttributedString(string: message.content, attributes: contentAttr))
			self.contentLabel.attributedText = string
		}
	}
	
	open func hide(automatically: Bool) {
		UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5, options: [], animations: {
			self.view.transform = CGAffineTransform(translationX: 0, y: -self.view.bounds.height)
		}, completion: { completed in
			self.willMove(toParentViewController: nil)
			self.view.removeFromSuperview()
			self.removeFromParentViewController()
			self.didMove(toParentViewController: nil)
			self.didHide?(automatically)
		})
	}
	
	func mainButtonTapped(_ sender: UIButton?) {
		if let convo = self.message.conversation {
			Utilities.postNotification(ConversationKit.notifications.conversationSelected, object: convo)
		}
	}
}


extension MessageReceivedDropDown {
	public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		self.checkForHidden()
	}
	
	public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
		self.checkForHidden()
	}
	
	public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		self.checkForHidden()
	}
	
	func checkForHidden() {
		if let sv = self.scrollView , sv.contentOffset.y >= sv.bounds.height {
			self.hide(automatically: false)
		}
	}
	
	
}
