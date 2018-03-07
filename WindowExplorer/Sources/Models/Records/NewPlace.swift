//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import MapKit

class NewPlace {

    let id: Int
    let title: String
    let coordinate: CLLocationCoordinate2D
    let relatedSchoolIDs: [Int]
    let relatedOrganizationIDs: [Int]
    let relatedObjectsIDs: [Int]
    let relatedEventIDs: [Int]

    private struct Keys {
        static let id = "id"
        static let title = "title"
        static let type = "type"
        static let coordinate = "coordinate"
        static let schoolIDs = "relatedSchoolIDs"
        static let organizationIDs = "relatedOrganizationIDs"
        static let objectIDs = "relatedObjectIds"
        static let eventIDs = "relatedEventIds"
    }


    // MARK: Init

    init?(json: JSON) {
        guard
            let id = json[Keys.id] as? Int,
            let title = json[Keys.title] as? String,
            let coordinate = json[Keys.type] as? CLLocationCoordinate2D else {
                return nil
        }

        self.id = id
        self.title = title
        self.coordinate = coordinate
        self.relatedSchoolIDs = json[Keys.schoolIDs] as? [Int] ?? []
        self.relatedOrganizationIDs = json[Keys.organizationIDs] as? [Int] ?? []
        self.relatedObjectsIDs = json[Keys.objectIDs] as? [Int] ?? []
        self.relatedEventIDs = json[Keys.eventIDs] as? [Int] ?? []
    }
}
