//  Copyright © 2018 JABT. All rights reserved.

import Foundation


enum SettingsNotification: String {
    case unpair
    case ungroup
    case sync
    case split
    case merge
    case filter
    case labels
    case miniMap
    case reset

    var name: Notification.Name {
        return Notification.Name(rawValue: rawValue)
    }

    static var allValues: [SettingsNotification] {
        return [.unpair, .ungroup, .sync, .split, .merge, .filter, .labels, .miniMap, .reset]
    }
}
