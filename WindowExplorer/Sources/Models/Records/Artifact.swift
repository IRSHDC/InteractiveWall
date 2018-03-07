//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import MapKit

class Artifact {

    let id: Int
    let title: String
    let shortTitle: String?
    let subtitle: String?
    let description: String?
    let mediaTitle: String?
    let mediaUrl: URL?
    let thumbnailUrl: URL?
    let comments: String?
    let themeIDs: [Int]
    let mediaPath: String?
    var relatedSchools: [School]?
    var relatedOrganizations: [Organization]?
    var relatedArtifacts: [Artifact]?
    var relatedEvents: [Event]?

    private struct Keys {
        static let id = "id"
        static let title = "title"
        static let shortTitle = "shortTitle"
        static let subtitle = "subtitle"
        static let description = "description"
        static let mediaTitle = "mediaTitle"
        static let mediaUrl = "mediaUrl"
        static let thumbnailUrl = "mediaThumbnailUrl"
        static let comments = "curatorialComments"
        static let themeIDs = "themeIDs"
        static let mediaPath = "mediaPath"
        static let schools = "schools"
        static let organizations = "organizations"
        static let artifacts = "artifacts"
        static let events = "events"
    }


    // MARK: Init

    init?(json: JSON) {
        guard let id = json[Keys.id] as? Int, let title = json[Keys.title] as? String else {
            return nil
        }

        self.id = id
        self.title = title
        self.shortTitle = json[Keys.shortTitle] as? String
        self.subtitle = json[Keys.subtitle] as? String
        self.description = json[Keys.description] as? String
        self.mediaTitle = json[Keys.mediaTitle] as? String
        self.mediaUrl = URL.from(json[Keys.mediaUrl] as? String)
        self.thumbnailUrl = URL.from(json[Keys.thumbnailUrl] as? String)
        self.comments = json[Keys.comments] as? String
        self.themeIDs = json[Keys.themeIDs] as? [Int] ?? []
        self.mediaPath = json[Keys.mediaPath] as? String

        if let schoolsJSON = json[Keys.schools] as? [JSON] {
            let schools = schoolsJSON.flatMap { School(json: $0) }
            self.relatedSchools = schools
        }
        if let organizationsJSON = json[Keys.organizations] as? [JSON] {
            let organizations = organizationsJSON.flatMap { Organization(json: $0) }
            self.relatedOrganizations = organizations
        }
        if let artifactsJSON = json[Keys.artifacts] as? [JSON] {
            let artifacts = artifactsJSON.flatMap { Artifact(json: $0) }
            self.relatedArtifacts = artifacts
        }
        if let eventsJSON = json[Keys.events] as? [JSON] {
            let events = eventsJSON.flatMap { Event(json: $0) }
            self.relatedEvents = events
        }
    }
}
