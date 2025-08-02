import Testing
@testable import Sqlite2CoreData
import CoreData
import SwiftData

@Test func example() async throws {
    
    let modelURL = Bundle.module.url(forResource: "Chinook", withExtension: "momd")!
    guard let mom = NSManagedObjectModel.init(contentsOf: modelURL) else {
        throw TestError.canNotReadModel
    }


    let dbURL = Bundle.module.url(forResource: "Chinook", withExtension: "sqlite")!
    let store = NSPersistentContainer(name: "Chinook", managedObjectModel: mom)
    store.persistentStoreDescriptions = [store.persistentStoreDescriptions.first!]
    store.persistentStoreDescriptions.first?.url = dbURL
    store.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    store.persistentStoreDescriptions.first?.isReadOnly = false
    store.persistentStoreDescriptions.first?.shouldAddStoreAsynchronously = false
    store.loadPersistentStores { _, _ in
        
    }
    let context = store.newBackgroundContext()
//    if #available(macOS 15, *) {
//        let scheme = Schema([
//            Album.self, Artist.self, Customer.self, Employee.self, Genre.self, Invoice.self, Invoiceline.self, Mediatype.self, Playlist.self, Track.self,
//        ])
//        let newURL = URL(fileURLWithPath: "/tmp/foobar/test/Chinook.sqlite")
////        if FileManager.default.fileExists(atPath: newURL.path) {
////            try FileManager.default.removeItem(at: newURL)
////        }
////       try FileManager.default.copyItem(at: dbURL, to: newURL)
//        let configuration = DefaultStore.Configuration.init(schema: scheme, url: newURL, allowsSave: true)
//        let container = try ModelContainer.init(for: scheme, configurations: configuration)
//        print(newURL)
//        let cotext = ModelContext(container)
//        let models:[Album] = try cotext.fetch(.init(predicate: .true))
//        
//    }
    let result:NSAsynchronousFetchResult<CDAlbum> = try await withCheckedThrowingContinuation { continuation in
        let request = NSAsynchronousFetchRequest(fetchRequest: CDAlbum.fetchRequest()) {
            nonisolated(unsafe)
            let k = $0
            continuation.resume(returning: k)
        }
        context.perform {
            do {
                try context.execute(request)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    let list = result.finalResult ?? []
    for album in list {
        if let count = album.track?.count, count > 1 {
            
        }
        
    }
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}


enum TestError: Error {
    case canNotReadModel
}
