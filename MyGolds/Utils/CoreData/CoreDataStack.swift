//
//  CoreDataStack.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 7.03.2024.
//

import Foundation
import CoreData

final class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MyGolds")
        
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load persistent stores: \(error.localizedDescription)")
            }
        }
        
        return container
    }()
    
    private init() {}
    
    // Save changes
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // Create
    func create<T: NSManagedObject>(entityName: String) -> T {
        let context = persistentContainer.viewContext
        return T(entity: NSEntityDescription.entity(forEntityName: entityName, in: context)!, insertInto: context)
    }
    
    // Read
    func fetch<T: NSManagedObject>(entityName: String, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [T] {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        do {
            let results = try context.fetch(fetchRequest)
            return results
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    // Update
    func getObject<T: NSManagedObject>(object: T) -> T? {
        let context = persistentContainer.viewContext
        guard let object = context.object(with: object.objectID) as? T else { return nil }
        return object
    }
    
    // Delete
    func delete<T: NSManagedObject>(object: T) {
        let context = persistentContainer.viewContext
        context.delete(object)
        saveContext()
    }
}
