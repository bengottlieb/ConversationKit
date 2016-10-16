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
	let imagesCacheURL: URL
	
	let dbName = "Conversations.db"
	let containerName = "ConversationKit"
	let imagesCacheDirectoryName = "Images"
	
	init(dbName: String) {
		let modelName = "ConversationKit"
		let mgr = FileManager.default
		let modelURL = Bundle(for: type(of: self)).url(forResource: modelName, withExtension: "momd")!
		let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
		let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, [.userDomainMask], true).first!
		let storeURL = URL(fileURLWithPath: cachesPath).appendingPathComponent(self.containerName).appendingPathComponent(self.dbName)
		imagesCacheURL = URL(fileURLWithPath: cachesPath).appendingPathComponent(self.containerName).appendingPathComponent(self.imagesCacheDirectoryName)
		do { try FileManager.default.createDirectory(at: imagesCacheURL, withIntermediateDirectories: true, attributes: nil) } catch {}

		if !FileManager.default.fileExists(atPath: storeURL.path) {
			ConversationKit.log("Creating database at \(storeURL.path)")
		}
		model = NSManagedObjectModel(contentsOf: modelURL)!
		persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		let parentURL = storeURL.deletingLastPathComponent()
		
		try! mgr.createDirectory(at: parentURL, withIntermediateDirectories: true, attributes: nil)
		
		var addedStore: NSPersistentStore?
		repeat {
			do {
				addedStore = try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
			} catch {
				try! mgr.removeItem(at: parentURL)
				try! mgr.createDirectory(at: parentURL, withIntermediateDirectories: true, attributes: nil)
			}
		} while addedStore == nil
		
		privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		privateContext.persistentStoreCoordinator = persistentStoreCoordinator
		privateContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		
		mainThreadContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		mainThreadContext.parent = privateContext
		mainThreadContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		
		super.init()
	}
	
	func setup() {
		
	}
	
	subscript(key: String) -> Any? {
		get {
			let metadata = self.persistentStoreCoordinator.persistentStores.first?.metadata
			return metadata?[key]
		}
		set {
			let store = self.persistentStoreCoordinator.persistentStores[0]
			store.metadata[key] = newValue
		}
	}
	
	func createWorkerContext() -> NSManagedObjectContext {
		let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		context.parent = self.mainThreadContext
		context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
		return context
	}
	
	func importBlock(_ block: @escaping (NSManagedObjectContext) -> Void) {
		let moc = self.createWorkerContext()
		moc.perform {
			block(moc)
			if moc.hasChanges { moc.safeSave(toDisk: true) }
		}
	}

	func clearAllCachedDataWithCompletion(_ completion: @escaping () -> Void) {
		ConversationKit.log("Clearing all data")
		let moc = self.privateContext
		self[Cloud.lastPendingFetchedAtKey] = nil
		
		moc.perform {
			moc.removeAllObjectsOfType(Message.entityName)
			moc.removeAllObjectsOfType(Speaker.entityName)
			do { try moc.save() } catch {}
			
			moc.reset()
			
			self.mainThreadContext.perform {
				self.mainThreadContext.reset()
				
				completion()
			}
		}
	}
}

extension NSManagedObjectContext {
	func removeAllObjectsOfType(_ name: String) {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
		let deleteAllRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
		do {
			try self.persistentStoreCoordinator?.execute(deleteAllRequest, with: self)
		} catch let error {
			ConversationKit.log("Error while removing all \(name) objects", error: error as NSError)
		}
	}
	
	func safeSave(toDisk: Bool) {
		if !self.hasChanges { return }

	//	print("Saving \(self), parent: \(self.parent)")
		
		do {
			try self.save()
			
			if toDisk, let parent = self.parent { parent.performAndWait {
				parent.safeSave(toDisk: true)
			} }
		} catch let error {
			ConversationKit.log("Error while saving database", error: error)
		}
	}
	
	func anyObject<Entity>(_ predicate: NSPredicate? = nil, sortBy: [NSSortDescriptor] = []) -> Entity? where Entity: NSManagedObject {
		if sortBy.count == 0 {
			for object in self.registeredObjects where object is Entity && !object.isFault {
				if predicate == nil || predicate!.evaluate(with: object) { return object as? Entity }
			}
		}
		
		let request = self.fetchRequest(Entity.entityName)
		if predicate != nil { request.predicate = predicate! }
		request.fetchLimit = 1
		if sortBy.count > 0 { request.sortDescriptors = sortBy }
		
		do {
			if let results = try self.fetch(request) as? [Entity] {
				return results.first
			}
		} catch let error {
			ConversationKit.log("Error executing fetch request: \(request)", error: error)
		}
		
		return nil
	}

	func allObjects<Entity>(_ predicate: NSPredicate? = nil, sortedBy: [NSSortDescriptor] = []) -> [Entity] where Entity: NSManagedObject {
		let request = self.fetchRequest(Entity.entityName)
		if predicate != nil { request.predicate = predicate! }
		if sortedBy.count > 0 { request.sortDescriptors = sortedBy }
		
		do {
			if let results = try self.fetch(request) as? [Entity] {
				return results
			}
		} catch let error {
			ConversationKit.log("Error executing fetch request: \(request)", error: error)
		}
		return []
	}
	
	func fetchRequest<Entity>(_ name: String) -> NSFetchRequest<Entity> where Entity: NSManagedObject {
		let request = NSFetchRequest<Entity>(entityName: name)
		
		return request
	}
	
	func insert(_ entityName: String) -> NSManagedObject {
		return NSEntityDescription.insertNewObject(forEntityName: entityName, into: self)
	}
	
	func insertObject<T>() -> T where T:NSManagedObject {
		return self.insert(T.entityName) as! T
	}
}

extension NSManagedObject {
	subscript(key: String) -> AnyObject? {
		get { return self.value(forKey: key) as AnyObject? }
		set { self.setValue(newValue, forKey: key) }
	}
	
	var moc: NSManagedObjectContext? { return self.managedObjectContext }
	func objectInContext(_ moc: NSManagedObjectContext) -> NSManagedObject? {
		return moc.object(with: self.objectID)
	}
	
	func log() { ConversationKit.log("\(self)") }
	
	class var entityName: String {
		return "\(self)"
	}
	
	func deleteFromContext() {
		self.managedObjectContext?.delete(self)
	}
}
