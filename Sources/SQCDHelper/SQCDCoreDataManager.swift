//
//  Untitled.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//

import CoreData
import Foundation


public class SQCDCoreDataManager: NSObject {
    
    private let momdPath:String
    private let outputDirPath:String
    private let lock = NSRecursiveLock()
    private lazy var _persistentStoreCoordinator:NSPersistentStoreCoordinator? = {[unowned self] in
        guard let mom = _managedObjectModel else {
            assertionFailure("\(Self.self) No model to generate a store")
            return nil
        }
        let dir = URL(fileURLWithPath: outputDirPath, isDirectory: true)
        do {
            let values = try dir.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                
            } else {
                let failureDescription = String(format: "Expected a folder to store application data, found a file (%@).", dir.path)
                assertionFailure(failureDescription)
                return nil
            }
        } catch let error as NSError {
            if (error.code == NSFileReadNoSuchFileError && error.domain == NSCocoaErrorDomain) {
                do {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                } catch {
                    assertionFailure("Failed to create output directory \(error)")
                    return nil
                }
            } else {
                assertionFailure("Can not handle this error \(error)")
                return nil
            }
        }
        
        let url = dir.appendingPathComponent(((momdPath as NSString).lastPathComponent as NSString).deletingPathExtension)
            .appendingPathExtension("sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: mom)
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
            return coordinator
        } catch {
            assertionFailure(error.localizedDescription)
            return nil
        }
    }()
    private lazy var _managedObjectModel:NSManagedObjectModel? = {[unowned self] in
        if let url = URL(string: momdPath) {
            return .init(contentsOf: url)
        }
        return nil
    }()

    private lazy var _managedObjectContext:NSManagedObjectContext? = {[unowned self] in
        guard let coordinator = _persistentStoreCoordinator else {
            assertionFailure("Failed to initalize store")
            return nil
        }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    
        context.persistentStoreCoordinator = coordinator
        return context
    }()
    
    
    @objc(initWithModelPath:outputDirectory:)
    public init(withModelPath modelPath: String, outputDirectory: String) {
        self.momdPath = modelPath
        self.outputDirPath = outputDirectory
        super.init()
        
    }
    
    
    @objc public var persistentStoreCoordinator:NSPersistentStoreCoordinator? {
        lock.withLock {
            return _persistentStoreCoordinator
        }
    }
    
    
    @objc public var managedObjectModel:NSManagedObjectModel? {
        lock.withLock {
            return _managedObjectModel
        }
    }
    
    @objc public var managedObjectContext:NSManagedObjectContext? {
        lock.withLock {
            return _managedObjectContext
        }
    }
    
    
}
