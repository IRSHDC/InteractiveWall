//  Copyright © 2017 JABT. All rights reserved.

import Foundation
import AppKit


class TapGestureRecognizer: NSObject, GestureRecognizer {

    var gestureUpdated: ((GestureRecognizer) -> Void)?
    var touchUpdated: ((GestureRecognizer, Touch) -> Void)?
    var position: CGPoint?
    private(set) var state = GestureState.possible

    private var positionForTouch = [Touch: CGPoint]()
    private var delayTap: Bool
    private var cancelOnMove: Bool

    private struct Constants {
        static let maximumDistanceMoved: CGFloat = 20
        static let minimumFingers = 1
        static let delayedTapDuration = 0.15
        static let recognizeDoubleTapMaxTime = 0.5
        static let recognizeDoubleTapMaxDistance: CGFloat = 40
    }


    // MARK: Init
    init(withDelay: Bool = false, cancelsOnMove: Bool = true) {
        self.delayTap = withDelay
        self.cancelOnMove = cancelsOnMove
    }


    // MARK: API

    func start(_ touch: Touch, with properties: TouchProperties) {
        positionForTouch[touch] = touch.position
        position = touch.position
        state = .began

        if delayTap {
            startDelayedTimer()
        } else {
            gestureUpdated?(self)
            touchUpdated?(self, touch)
            state = .recognized
        }
    }

    func move(_ touch: Touch, with properties: TouchProperties) {
        guard let initialPosition = positionForTouch[touch], state != .ended else {
            return
        }

        let delta = CGVector(dx: initialPosition.x - touch.position.x, dy: initialPosition.y - touch.position.y)
        let distance = sqrt(pow(delta.dx, 2) + pow(delta.dy, 2))
        if distance > Constants.maximumDistanceMoved {
            state = .failed
            if cancelOnMove {
                end(touch, with: properties)
            } else {
                touchUpdated?(self, touch)
                state = .ended
            }
        }
    }

    func end(_ touch: Touch, with properties: TouchProperties) {
        guard positionForTouch.keys.contains(touch) else {
            return
        }

        position = touch.position

        switch state {
        case .failed:
            gestureUpdated?(self)
        case .began:
            gestureUpdated?(self)
            fallthrough
        default:
            state = .ended
            gestureUpdated?(self)
            touchUpdated?(self, touch)
        }

        reset()
        positionForTouch.removeValue(forKey: touch)
    }

    func reset() {
        state = .possible
    }


    // MARK: Helpers

    private func startDelayedTimer() {
        Timer.scheduledTimer(withTimeInterval: Constants.delayedTapDuration, repeats: false) { [weak self] _ in
            self?.delayedTimerFired()
        }
    }

    private func delayedTimerFired() {
        if state == .began {
            gestureUpdated?(self)
            state = .recognized
        }
    }
}
