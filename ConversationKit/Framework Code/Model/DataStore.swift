//
//  Store.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/16/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import Foundation
import CoreData

class DataStore: NSObject {
	static var instance = DataStore(dbName: "Conversations.db")
	
	let model: NSManagedObjectModel
	let persistentStoreCoordinator: NSPersistentStoreCoordinator
	let mainThreadContext: NSManagedObjectContext
	let privateContext: NSManagedObjectContext
	
	init(dbName: String) {
		let modelName = "ConversationKit"
		let mgr = NSFileManager.defaultManager()
		let modelURL = NSBundle(forClass: self.dynamicType).URLForResource(modelName, withExtension: "momd")!
		let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
		let cachesPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, [.UserDomainMask], true).first!
		let storeURL = NSURL(fileURLWithPath: cachesPath).URLByAppendingPathComponent(dbName)
		print("Creating database at \(storeURL.absoluteString)")
		model = NSManagedObjectModel(contentsOfURL: modelURL)!
		persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		let parentURL = storeURL.URLByDeletingLastPathComponent!
		
		try! mgr.createDirectoryAtURL(parentURL, withIntermediateDirectories: true, attributes: nil)
		
		var addedStore: NSPersistentStore?
		repeat {
			do {
				addedStore = try persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options)
			} catch {
				try! mgr.removeItemAtURL(parentURL)
				try! mgr.createDirectoryAtURL(parentURL, withIntermediateDirectories: true, attributes: nil)
			}
		} while addedStore == nil
		
		privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
		privateContext.persistentStoreCoordinator = persistentStoreCoordinator
		
		mainThreadContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
		mainThreadContext.parentContext = privateContext
		
		super.init()
	}
	
	func setup() {
		
	}
	
	func createWorkerContext() -> NSManagedObjectContext {
		let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
		context.parentContext = self.mainThreadContext
		return context
	}
	
	func importBlock(block: (NSManagedObjectContext) -> Void) {
		let moc = self.createWorkerContext()
		moc.performBlock {
			block(moc)
			if moc.hasChanges { moc.safeSave() }
		}
	}

}

extension NSManagedObjectContext {
	public var localSpeaker: Speaker {
		if let spkr: Speaker = self.anyObject(NSPredicate(format: "isLocalUser = true")) {
			return spkr
		}
		
		let localSpeaker: Speaker = self.insertObject()
		localSpeaker["isLocalUser"] = true
		localSpeaker.identifier = ""
		return localSpeaker
	}
	
	public func speakerWithIdentifier(id: String) -> Speaker {
		if let spkr: Speaker = self.anyObject(NSPredicate(format: "identifier = %@", id)) {
			return spkr
		}
		
		let localSpeaker: Speaker = self.insertObject()
		localSpeaker.identifier = id
		return localSpeaker
	}
	
	func safeSave() {
		do {
			try self.save()
			self.parentContext?.safeSave()
		} catch let error {
			print("Error while saving database: \(error)")
		}
	}
	
	public func anyObject<T where T:NSManagedObject>(predicate: NSPredicate? = nil, sortBy: [NSSortDescriptor] = []) -> T? {
		if sortBy.count == 0 {
			for object in self.registeredObjects where object is T && !object.fault {
				if predicate == nil || predicate!.evaluateWithObject(object) { return object as? T }
			}
		}
		
		let request = self.fetchRequest(T.entityName)
		if predicate != nil { request.predicate = predicate! }
		request.fetchLimit = 1
		if sortBy.count > 0 { request.sortDescriptors = sortBy }
		
		do {
			if let results = try self.executeFetchRequest(request) as? [NSManagedObject] {
				return results.count > 0 ? results[0] as? T : nil
			}
		} catch let error {
			print("Error (\(error) executing fetch request: \(request)")
		}
		
		return nil
	}

	public func fetchRequest(name: String) -> NSFetchRequest {
		let request = NSFetchRequest(entityName: name)
		
		return request
	}
	
	public func insertObject<T where T:NSManagedObject>() -> T {
		let entityName = T.entityName
		let object = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: self)
		return object as! T
	}
}

public extension NSManagedObject {
	public subscript(key: String) -> AnyObject? {
		get { return self.valueForKey(key) }
		set { self.setValue(newValue, forKey: key) }
	}
	
	public var moc: NSManagedObjectContext? { return self.managedObjectContext }
	public func objectInContext(moc: NSManagedObjectContext) -> NSManagedObject? {
		return moc.objectWithID(self.objectID)
	}
	
	public func log() { print("\(self)") }
	
	class var entityName: String {
		return "\(self)"
	}
	
	func deleteFromContext() {
		self.managedObjectContext?.deleteObject(self)
	}
}