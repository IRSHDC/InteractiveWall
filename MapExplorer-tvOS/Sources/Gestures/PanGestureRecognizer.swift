//  Copyright © 2017 JABT. All rights reserved.

import Foundation
import UIKit

class PanGestureRecognizer: NSObject, GestureRecognizer {

    private struct Constants {
        static let recognizedThreshhold: CGFloat = 100
        static let minimumFingers = 1
    }

    var state = UIGestureRecognizerState.possible
    var delta = CGVector.zero
    var lastPosition: CGPoint?
    var fingers: Int

    var gestureUpdated: ((GestureRecognizer) -> Void)?
    var gestureRecognized: ((GestureRecognizer) -> Void)?

    init(withFingers fingers: Int = Constants.minimumFingers) {
        precondition(fingers >= Constants.minimumFingers, "\(fingers) is an invalid number of fingers, errors will occur")
        self.fingers = fingers
        super.init()
    }

    func start(_ touch: Touch, with properties: TouchProperties) {
        if state == .began {
            state = .failed
        } else if state == .possible && properties.touchCount == fingers {
            state = .began
            lastPosition = properties.cog
        }
    }

    func move(_ touch: Touch, with properties: TouchProperties) {
        guard let lastPosition = lastPosition else {
            return
        }

        switch state {
        case .began where abs(properties.cog.x - lastPosition.x) + abs(properties.cog.y - lastPosition.y) > Constants.recognizedThreshhold:
            state = .recognized
            gestureRecognized?(self)
        case .recognized:
            delta = CGVector(dx: properties.cog.x - lastPosition.x, dy: properties.cog.y - lastPosition.y)
            self.lastPosition = properties.cog
            gestureUpdated?(self)
        default:
            return
        }
    }

    func end(_ touch: Touch, with properties: TouchProperties) {
        if properties.touchCount.isZero {
            state = .possible
        } else {
            state = .failed
        }
    }

    func reset() {
        state = .possible
        lastPosition = nil
        delta = .zero
    }

    func invalidate() {
        state = .failed
    }
}