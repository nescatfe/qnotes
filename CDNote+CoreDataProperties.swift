//
//  CDNote+CoreDataProperties.swift
//  Qnote
//
//  Created by coolskyz on 03/10/24.
//
//

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

}

extension CDNote : Identifiable {

}
