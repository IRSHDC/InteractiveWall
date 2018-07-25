//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import Cocoa


extension String {
    func componentsSeparatedBy(separators: String) -> [String] {
        let separatorSet = CharacterSet(charactersIn: separators)
        return components(separatedBy: separatorSet).filter({ !$0.isEmpty })
    }
}
