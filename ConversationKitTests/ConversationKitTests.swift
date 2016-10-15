//
//  ConversationKitTests.swift
//  ConversationKitTests
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import XCTest
@testable import ConversationKit

class ConversationKitTests: XCTestCase {
	let store = DataStore(dbName: "TestDB.db")
	
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	func testCreateConversation() {
		let moc = self.store.createWorkerContext()
		
		moc.perform {
			let speaker1: Speaker = Speaker.speaker(withIdentifier: "1")
			let speaker2: Speaker = Speaker.localSpeaker
			let convo = Conversation.conversationBetween([speaker1, speaker2])
			
			convo.createNewMessage("Hello")
			
			moc.safeSave()
			
		}
	}
	
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testxPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
