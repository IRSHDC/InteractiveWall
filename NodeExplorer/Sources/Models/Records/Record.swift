//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import AppKit
import MapKit


struct RecordGroup {
    let type: RecordType
    let records: [Record]
}


class Record: Hashable {

    let type: RecordType
    let id: Int
    let title: String
    let shortTitle: String
    let description: String?
    let comments: String?
    let date: String?
    var coordinate: CLLocationCoordinate2D?
    var media = [Media]()
    let relatedSchoolIDs: [Int]
    let relatedOrganizationIDs: [Int]
    let relatedArtifactIDs: [Int]
    let relatedEventIDs: [Int]
    let relatedThemeIDs: [Int]
    var relatedRecordsForType = [RecordType: Set<Record>]()
    lazy var priority = PriorityOrder.priority(for: self)

    var relatedRecords: [Record] {
        return relatedRecordsForType.values.reduce([], +)
    }

    var proxy: RecordProxy {
        return RecordProxy(id: id, type: type)
    }

    var hashValue: Int {
        return id.hashValue ^ type.hashValue
    }

    private struct Keys {
        static let id = "id"
        static let title = "title"
        static let shortTitle = "shortTitle"
        static let description = "description"
        static let comments = "curatorialComments"
        static let date = "date"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let mediaTitles = "mediaTitles"
        static let media = "mediaPaths"
        static let localMedia = "fullMediaPaths"
        static let thumbnails = "thumbnailPaths"
        static let localThumbnails = "fullThumbnailPaths"
        static let schoolIDs = "relatedSchoolIDs"
        static let organizationIDs = "relatedOrganizationIDs"
        static let artifactIDs = "relatedArtifactIDs"
        static let eventIDs = "relatedEventIDs"
        static let themeIDs = "relatedThemeIDs"
    }


    // MARK: Init

    init?(type: RecordType, json: JSON) {
        guard let id = json[Keys.id] as? Int, let title = json[Keys.title] as? String, let shortTitle = json[Keys.shortTitle] as? String else {
            return nil
        }

        self.type = type
        self.id = id
        self.title = title
        self.shortTitle = shortTitle
        self.comments = json[Keys.comments] as? String
        self.date = json[Keys.date] as? String
        self.description = json[Keys.description] as? String
        self.relatedSchoolIDs = json[Keys.schoolIDs] as? [Int] ?? []
        self.relatedOrganizationIDs = json[Keys.organizationIDs] as? [Int] ?? []
        self.relatedArtifactIDs = json[Keys.artifactIDs] as? [Int] ?? []
        self.relatedEventIDs = json[Keys.eventIDs] as? [Int] ?? []
        self.relatedThemeIDs = json[Keys.themeIDs] as? [Int] ?? []

        if let latitude = json[Keys.latitude] as? Double, let longitude = json[Keys.longitude] as? Double {
            self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        if let urlStrings = json[Keys.media] as? [String], let localURLStrings = json[Keys.localMedia] as? [String], let thumbnailStrings = json[Keys.thumbnails] as? [String], let localThumbnailStrings = json[Keys.localThumbnails] as? [String] {
            let urls = urlStrings.compactMap { URL.from(Configuration.serverURL + $0) }
            let localURLs = localURLStrings.map { URL(fileURLWithPath: $0) }
            let thumbnails = thumbnailStrings.compactMap { URL.from(Configuration.serverURL + $0) }
            let localThumbnails = localThumbnailStrings.map { URL(fileURLWithPath: $0) }
            let titles = json[Keys.mediaTitles] as? [String] ?? []
            for (url, localURL, thumbnail, localThumbnail) in zip(seq1: urls, seq2: localURLs, seq3: thumbnails, seq4: localThumbnails) {
                media.append(Media(url: url, localURL: localURL, thumbnail: thumbnail, localThumbnail: localThumbnail, title: titles.at(index: media.count), color: type.color))
            }
        }
    }


    // MARK: API

    func shortestTitle() -> String {
        if shortTitle.isEmpty {
            return title
        }

        return shortTitle.count < title.count ? shortTitle : title
    }

    func relatedRecords(type: RecordType) -> [Record] {
        guard let records = relatedRecordsForType[type] else {
            return []
        }

        return Array(records)
    }

    func relate(to record: Record) {
        if relatedRecordsForType[record.type] == nil {
            relatedRecordsForType[record.type] = [record]
        } else {
            relatedRecordsForType[record.type]?.insert(record)
        }
    }


    // MARK: Hashable

    static func == (lhs: Record, rhs: Record) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type && lhs.title == rhs.title
    }
}
