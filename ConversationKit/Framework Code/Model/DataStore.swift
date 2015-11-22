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

		if !NSFileManager.defaultManager().fileExistsAtPath(storeURL.path!) {
			ConversationKit.log("Creating database at \(storeURL.path!)")
		}
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
		privateContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		
		mainThreadContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
		mainThreadContext.parentContext = privateContext
		mainThreadContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		
		super.init()
	}
	
	func setup() {
		
	}
	
	subscript(key: String) -> AnyObject? {
		get {
			let store = self.persistentStoreCoordinator.persistentStores[0]
			return store.metadata[key]
		}
		set {
			let store = self.persistentStoreCoordinator.persistentStores[0]
			store.metadata[key] = newValue
		}
	}
	
	func createWorkerContext() -> NSManagedObjectContext {
		let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
		context.parentContext = self.mainThreadContext
		context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		return context
	}
	
	func importBlock(block: (NSManagedObjectContext) -> Void) {
		let moc = self.createWorkerContext()
		moc.performBlock {
			block(moc)
			if moc.hasChanges { moc.safeSave() }
		}
	}

	func clearAllCachedDataWithCompletion(completion: () -> Void) {
		ConversationKit.log("Clearing all data")
		let moc = self.privateContext
		moc.performBlock {
			moc.removeAllObjectsOfType(Message.entityName)
			moc.removeAllObjectsOfType(Speaker.entityName)
			do { try moc.save() } catch {}
			
			moc.reset()
			
			self.mainThreadContext.performBlock {
				self.mainThreadContext.reset()
				
				completion()
			}
		}
	}
}

extension NSManagedObjectContext {
	func removeAllObjectsOfType(name: String) {
		let fetchRequest = NSFetchRequest(entityName: name)
		let deleteAllRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
		do {
			try self.persistentStoreCoordinator?.executeRequest(deleteAllRequest, withContext: self)
		} catch let error {
			ConversationKit.log("Error while removing all \(name) objects: \(error)")
		}
	}
	
	func safeSave() {
		do {
			try self.save()
			self.parentContext?.safeSave()
		} catch let error {
			ConversationKit.log("Error while saving database: \(error)")
		}
	}
	
	func anyObject<T where T:NSManagedObject>(predicate: NSPredicate? = nil, sortBy: [NSSortDescriptor] = []) -> T? {
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
			ConversationKit.log("Error (\(error) executing fetch request: \(request)")
		}
		
		return nil
	}

	func allObjects<T where T:NSManagedObject>(predicate: NSPredicate? = nil, sortedBy: [NSSortDescriptor] = []) -> [T] {
		let request = self.fetchRequest(T.entityName)
		if predicate != nil { request.predicate = predicate! }
		if sortedBy.count > 0 { request.sortDescriptors = sortedBy }
		
		do {
			if let results = try self.executeFetchRequest(request) as? [T] {
				return results
			}
		} catch let error {
			ConversationKit.log("Error (\(error) executing fetch request: \(request)")
		}
		return []
	}
	
	func fetchRequest(name: String) -> NSFetchRequest {
		let request = NSFetchRequest(entityName: name)
		
		return request
	}
	
	func insert(entityName: String) -> NSManagedObject {
		return NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: self)
	}
	
	func insertObject<T where T:NSManagedObject>() -> T {
		return self.insert(T.entityName) as! T
	}
}

extension NSManagedObject {
	subscript(key: String) -> AnyObject? {
		get { return self.valueForKey(key) }
		set { self.setValue(newValue, forKey: key) }
	}
	
	var moc: NSManagedObjectContext? { return self.managedObjectContext }
	func objectInContext(moc: NSManagedObjectContext) -> NSManagedObject? {
		return moc.objectWithID(self.objectID)
	}
	
	func log() { ConversationKit.log("\(self)") }
	
	class var entityName: String {
		return "\(self)"
	}
	
	func deleteFromContext() {
		self.managedObjectContext?.deleteObject(self)
	}
}