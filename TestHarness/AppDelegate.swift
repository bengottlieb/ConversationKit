//
//  AppDelegate.swift
//  TestHarness
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit
import ConversationKit
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?


	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		ConversationKit.configureNotifications(application)

		ConversationKit.feedbackLevel = .development
		ConversationKit.fetchAccountIdentifier { identifier in
			guard let ident = identifier else { return }
			ConversationKit.setupLocalSpeaker(ident) { success in
				Speaker.localSpeaker.tags = ["tester"]
				Speaker.localSpeaker.save { success in
					print("saved local speaker \(success)")
				}
			}
		}
		
		self.window = UIWindow(frame: UIScreen.main.bounds)
		self.window?.rootViewController = UINavigationController(rootViewController: TestViewController(conversation: nil))
		
		self.window?.makeKeyAndVisible()
		ConversationKit.messageDisplayWindow = self.window
		
		
		// Override point for customization after application launch.
		return true
	}

	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		ConversationKit.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
	}

	func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, withResponseInfo responseInfo: [AnyHashable: Any], completionHandler: @escaping () -> Void) {
		
		ConversationKit.application(application, handleActionWithIdentifier: identifier, forLocalNotification: notification, withResponseInfo: responseInfo, completionHandler: completionHandler)
	}

}

