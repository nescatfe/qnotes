import Foundation
import CoreData

extension CDNote {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDNote> {
        return NSFetchRequest<CDNote>(entityName: "CDNote")
    }

    @NSManaged public var content: String?
    @NSManaged public var id: String?
    @NSManaged public var isPinned: Bool
    @NSManaged public var needsSync: Bool
    @NSManaged public var timestamp: Date?
    @NSManaged public var userId: String?
    @NSManaged public var syncState: Int16

    var syncStateEnum: SyncState {
        get {
            return SyncState(rawValue: Int(syncState)) ?? .notSynced
        }
        set {
            syncState = Int16(newValue.rawValue)
        }
    }
}

extension CDNote : Identifiable {
}

// Add this extension to define the SyncState enum with raw values
extension SyncState: RawRepresentable {
    typealias RawValue = Int
    
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .notSynced
        case 1: self = .syncing
        case 2: self = .synced
        default: return nil
        }
    }
    
    var rawValue: Int {
        switch self {
        case .notSynced: return 0
        case .syncing: return 1
        case .synced: return 2
        }
    }
}