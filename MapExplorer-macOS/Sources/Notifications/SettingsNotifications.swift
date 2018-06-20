//  Copyright © 2018 JABT. All rights reserved.

import Foundation


enum SettingsNotification: String {
    case split
    case merge
    case filter
    case labels
    case miniMap

    var name: Notification.Name {
        return Notification.Name(rawValue: rawValue)
    }

    static var allValues: [SettingsNotification] {
        return [.split, .merge, .filter, .labels, .miniMap]
    }
}
