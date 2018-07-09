//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import Cocoa


private struct Constants {
    static let listItemsPerRow: CGFloat = 1
    static let imageItemsPerRow: CGFloat = 3
}


enum RelatedItemViewLayout {
    case list
    case grid

    var identifier: NSUserInterfaceItemIdentifier {
        switch self {
        case .list:
            return RelatedItemListView.identifier
        case .grid:
            return RelatedItemImageView.identifier
        }
    }

    var itemSize: CGSize {
        switch self {
        case .list:
            return CGSize(width: style.relatedRecordsListItemWidth, height: style.relatedRecordsListItemHeight)
        case .grid:
            return CGSize(width: style.relatedRecordsImageItemWidth, height: style.relatedRecordsImageItemHeight)
        }
    }

    var rowWidth: CGFloat {
        switch self {
        case .list:
            let itemsPerRow = Constants.listItemsPerRow
            return style.relatedRecordsListItemWidth * itemsPerRow + style.relatedRecordsItemSpacing * (itemsPerRow - 1)
        case .grid:
            let itemsPerRow = Constants.imageItemsPerRow
            return style.relatedRecordsImageItemWidth * itemsPerRow + style.relatedRecordsItemSpacing * (itemsPerRow - 1)
        }
    }

    var itemsPerRow: CGFloat {
        switch self {
        case .list:
            return Constants.listItemsPerRow
        case .grid:
            return Constants.imageItemsPerRow
        }
    }
}
