//  Copyright © 2018 JABT. All rights reserved.

import Foundation

enum WindowType: Equatable {
    case record(RecordDisplayable)
    case image(Media)
    case player(Media)
    case pdf(Media)
    case search
    case menu
    case settings
    case border
    case testimony

    init?(for media: Media) {
        switch media.type {
        case .image:
            self = .image(media)
        case .video:
            self = .player(media)
        case .pdf:
            self = .pdf(media)
        case .unknown:
            return nil
        }
    }

    var size: CGSize {
        switch self {
        case .record:
            return style.recordWindowSize
        case .image:
            return style.imageWindowSize
        case .player:
            return style.playerWindowSize
        case .pdf:
            return style.pdfWindowSize
        case .search:
            return style.searchWindowSize
        case .menu:
            return style.menuWindowSize
        case .settings:
            return style.settingsWindowSize
        case .border:
            return style.borderWindowSize
        case .testimony:
            return style.testimonyWindowSize
        }
    }

    static func == (lhs: WindowType, rhs: WindowType) -> Bool {
        switch (lhs, rhs) {
        case let (.record(lhsModel), .record(rhsModel)):
            return lhsModel.type == rhsModel.type && lhsModel.id == rhsModel.id
        case let (.image(lhsMedia), .image(rhsMedia)):
            return lhsMedia == rhsMedia
        case let (.player(lhsMedia), .player(rhsMedia)):
            return lhsMedia == rhsMedia
        case let (.pdf(lhsMedia), .pdf(rhsMedia)):
            return lhsMedia == rhsMedia
        default:
            return false
        }
    }
}
