//
//  Persistence.swift
//  PreProcess
//
//  Created by Shaun Narayan on 27/02/23.
//

import CoreData
import SQLite
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

///
/// This handles removing dangling refs that may have occurd due to a bug in delete_episode
///
class ModelMigration1to2: NSEntityMigrationPolicy {
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Document")
        let context = manager.sourceContext
        let results = try context.fetch(request)
        for res in results {
            let ep = res.value(forKey: "episode") as! NSManagedObject
            let start = ep.value(forKey:"start")
            if start == nil {
                log.info("Culling episode \(res.value(forKey: "path") ?? "?")")
                context.delete(res)
            }
        }
        try super.begin(mapping, with: manager)
    }
}

///
/// Bunch of data representing the current application context
///
struct iRunningApplication {
    let bundleID: String
    let isActive: Bool
    let localizedName: String?
}
struct PreProcessAppContext {
#if os(macOS)
    let front:NSRunningApplication
#else
    let front: iRunningApplication
#endif
    var title: String
    var context: String
    let isPrivate: Bool
}

///
/// CoreData style wrapper for Intervals so it is observable in the UI
///
class PreProcessInterval: ObservableObject, Identifiable, Equatable, Hashable {
    static func == (lhs: PreProcessInterval, rhs: PreProcessInterval) -> Bool {
        return (lhs.from == rhs.from) && (lhs.to == rhs.to)
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    @Published var from: Date
    @Published var to: Date
    @Published var episode: Episode
    @Published var document: String
    @Published var snippet: String?
    
    init(from: Date, to: Date, episode: Episode, document: String, snippet: String? = nil) {
        self.from = from
        self.to = to
        self.episode = episode
        self.document = document
        self.snippet = snippet
    }
    
    var id: String { "\(self.from.timeIntervalSinceReferenceDate)" }
}

///
/// All stored data will be rooted to this location. It defaults to application support for the bundle,
/// and defers to a user preference if set
///
func homeDirectory() -> URL {
    let defaults = UserDefaults(suiteName: "group.io.preprocess.ios")!
    let home = defaults.string(forKey: "PREPROCESS_HOME")
    if home != nil && FileManager.default.fileExists(atPath: home!) {
        return URL(filePath: home!)
    }
#if os(macOS)
    let url: URL = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("PreProcess"))!
#else
    let url: URL = (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.io.preprocess.ios")!.appendingPathComponent("PreProcess"))
#endif
    return url
}

///
/// Format the title for an episode given its start time and unformatted title
///
func urlForEpisode(start: Date?, title: String?) -> URL {
    if title!.count > 256 {
        log.warning("Title was very large \(title ?? "")")
    }
    var url: URL = homeDirectory()
    let components = Calendar.current.dateComponents([.year, .month, .day], from: start ?? Date())
    url = url.appendingPathComponent("\(components.year ?? 0)")
    url = url.appendingPathComponent("\(components.month ?? 0)")
    url = url.appendingPathComponent("\(components.day ?? 0)")
    url = url.appendingPathComponent("\(title!).mov")
    return url
}

///
/// Helper struct for accessing Interval fields from result sets
///
struct IntervalExpression {
    public static let id = Expression<Int64>("id")
    public static let from = Expression<Double>("from")
    public static let to = Expression<Double>("to")
    public static let episodeStart = Expression<Double>("episode_start")
    public static let document = Expression<String>("document")
    public static let snippet = Expression<String>(literal: "snippet(Interval, -1, '', '', '', 5)")
}

class PersistenceController {
    static let shared = PersistenceController()

    var container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "PreProcess")
    }
    
    func reload() {
        let storeDirectory = homeDirectory()
        let url = storeDirectory.appendingPathComponent("PreProcess.sqlite")
        let description = NSPersistentStoreDescription(url: url)
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true

        // Clean up existing stores
        let coordinator = container.persistentStoreCoordinator
        let stores = coordinator.persistentStores
        for store in stores {
            do {
                try coordinator.remove(store)
            } catch {
                fatalError("Failed to remove store: \(error)")
            }
        }

        // Load persistent stores in the new location
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
