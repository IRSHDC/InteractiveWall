//  Copyright © 2017 JABT. All rights reserved.

import Foundation
import AppKit


/// Used to define the behavior of a PinchGestureRecognizer as its receiving move updates.
fileprivate enum PinchBehavior {
    case growing
    case shrinking
    case idle
}


class PinchGestureRecognizer: NSObject, GestureRecognizer {

    private struct Constants {
        static let initialScale: CGFloat = 1
        static let minimumFingers = 2
        static let minimumSpreadUpdateThreshold: CGFloat = 0.05
        static let minimumBehaviorChangeThreshold: CGFloat = 15
        static let updateTimeInterval: Double = 1 / 60
        static let minimumDeltaUpdateThreshold: Double = 4
    }

    var gestureUpdated: ((GestureRecognizer) -> Void)?
    private(set) var lastPosition: CGPoint!
    private(set) var state = GestureState.possible
    private(set) var scale: CGFloat = Constants.initialScale
    private var spreads = LastTwo<CGFloat>()
    private var behavior = PinchBehavior.idle
    private var timeOfLastUpdate: Date!
    private var lastSpreadSinceUpdate: CGFloat!
    private let fingers: Int

    private(set) var delta = CGVector.zero
    private(set) var locations = LastTwo<CGPoint>()
    private var positionForTouch = [Touch: CGPoint]()
    private var cumulativeDelta = CGVector.zero

    
    // MARK: Init

    init(withFingers fingers: Int = Constants.minimumFingers) {
        precondition(fingers >= Constants.minimumFingers, "\(fingers) is an invalid number of fingers")
        self.fingers = fingers
        super.init()
    }


    // MARK: API

    func start(_ touch: Touch, with properties: TouchProperties) {

        positionForTouch[touch] = touch.position

        guard fingers == properties.touchCount else {
            return
        }

        switch state {
        case .momentum:
            // This may need changing, remporary fix insite of reset
            reset()
            fallthrough
        case .possible:
            momentumTimer?.invalidate()
            cumulativeDelta = .zero
            spreads.add(properties.spread)
            lastPosition = properties.cog
            positionForTouch[touch] = touch.position
            locations.add(properties.cog)
            state = .began
            timeOfLastUpdate = Date()
            gestureUpdated?(self)
        default:
            return
        }
    }

    var count = 0

    func move(_ touch: Touch, with properties: TouchProperties) {

        guard let lastPositionOfTouch = positionForTouch[touch] else {
            return
        }

        positionForTouch[touch] = touch.position

        guard let lastSpread = spreads.last, let currentLocation = locations.last, properties.touchCount == fingers else {
            count += 1
            if count >= 20 {
                locations.clearSecondLast()
            }
            return
        }

        count = 0

        switch state {
        case .began:
            behavior = behavior(of: properties.spread)
            lastSpreadSinceUpdate = lastSpread
            state = .recognized
            fallthrough
        case .recognized:
            if shouldUpdate(with: properties.spread) {
                spreads.add(properties.spread)
                lastPosition = properties.cog
            } else if changedBehavior(from: lastSpread, to: properties.spread) {
                behavior = behavior(of: properties.spread)
                spreads.add(properties.spread)
            }

            // updating the cumulative delta, and the locations for momentum
            let touchVector = (touch.position - lastPositionOfTouch).asVector
            cumulativeDelta += touchVector / 2
            locations.add(currentLocation + touchVector / CGFloat(fingers))

            if shouldUpdate(for: timeOfLastUpdate) {
                // update the spread
                if behavior != .idle {
                    scale = properties.spread / lastSpreadSinceUpdate
                    lastSpreadSinceUpdate = properties.spread
                }

                // update the delta
                if cumulativeDelta.magnitude > Constants.minimumDeltaUpdateThreshold {
                    delta = cumulativeDelta
                    cumulativeDelta = .zero
                }

                // update time and send update
                timeOfLastUpdate = Date()
                gestureUpdated?(self)

                // Restting for the next one
                delta = .zero
                scale = Constants.initialScale
            }
        default:
            return
        }
    }

    func end(_ touch: Touch, with properties: TouchProperties) {

        positionForTouch.removeValue(forKey: touch)

        guard properties.touchCount.isZero else {
            return
        }

        let stateBeforeEnded = state

        state = .ended
        gestureUpdated?(self)

        if let velocity = panVelocity, let scale = pinchScale, stateBeforeEnded == .recognized {
            beginMomentum(velocity, scale)
        } else {
            reset()
            gestureUpdated?(self)
        }
    }

    func reset() {
        if state != .momentum {
            positionForTouch.removeAll()
        }

        state = .possible

        // resetting pinch
        scale = Constants.initialScale
        behavior = .idle
        lastPosition = nil
        spreads.clear()

        // resetting pan
        delta = .zero
        count = 0
    }


    // MARK: Momentium

    private struct Momentum {
        static let pinchThresholdMomentumScale: CGFloat = 0.0001
        static let pinchInitialFrictionFactor: CGFloat = 1.06
        static let pinchFrictionFactorScale: CGFloat = 0.004
        static let panInitialFrictionFactor = 1.05
        static let panFrictionFactorScale = 0.001
        static let panThresholdMomentumDelta: Double = 2
    }

    private var momentumTimer: Timer?
    private var panFrictionFactor = Momentum.panInitialFrictionFactor
    private var pinchFrictionFactor = Momentum.pinchInitialFrictionFactor

    private var panVelocity: CGVector? {
        guard let last = locations.last, let secondLast = locations.secondLast else { return nil }
        return CGVector(dx: last.x - secondLast.x, dy: last.y - secondLast.y)
    }
    private var pinchScale: CGFloat? {
        guard let last = spreads.last, let secondLast = spreads.secondLast else { return nil }
        return last / secondLast
    }
    
    private func beginMomentum(_ velocity: CGVector, _ scale: CGFloat) {
        state = .momentum
        panFrictionFactor = Momentum.panInitialFrictionFactor
        pinchFrictionFactor = Momentum.pinchInitialFrictionFactor
        delta = velocity * CGFloat(fingers)
        self.scale = scale
        gestureUpdated?(self)

        momentumTimer?.invalidate()
        momentumTimer = Timer.scheduledTimer(withTimeInterval: Constants.updateTimeInterval, repeats: true) { [weak self] _ in
            self?.updateMomentum()
        }
    }

    private func updateMomentum() {
        if abs(scale - 1) < Momentum.pinchThresholdMomentumScale {
            scale = Constants.initialScale
        }

        if delta.magnitude < Momentum.panThresholdMomentumDelta {
            delta = .zero
        }

        guard delta != .zero || scale != Constants.initialScale else {
            endMomentum()
            return
        }

        // updating pinch momentum
        scale -= 1
        scale /= pinchFrictionFactor
        scale += 1
        pinchFrictionFactor += Momentum.pinchFrictionFactorScale

        // updating pan momentum
        panFrictionFactor += Momentum.panFrictionFactorScale
        delta /= panFrictionFactor

        gestureUpdated?(self)
    }

    private func endMomentum() {
        momentumTimer?.invalidate()
        reset()
        gestureUpdated?(self)
    }


    // MARK: Pinch behavior

    /// Returns the behavior of the spread based off the current last spread.
    private func behavior(of spread: CGFloat) -> PinchBehavior {
        guard let lastSpread = spreads.last else {
            return .idle
        }

        return (spread - lastSpread > 0) ? .growing : .shrinking
    }

    /// Returns true if the given spread is of the same behavior type, or the current behavior is idle
    private func shouldUpdate(with newSpread: CGFloat) -> Bool {
        return behavior == behavior(of: newSpread) || behavior == .idle
    }

    /// Returns true if enough time has passed to send send the next update
    private func shouldUpdate(for time: Date) -> Bool {
        return abs(time.timeIntervalSinceNow) > Constants.updateTimeInterval
    }

    /// If the newSpread has a different behavior and surpasses the minimum threshold, returns true
    private func changedBehavior(from oldSpread: CGFloat, to newSpread: CGFloat) -> Bool {
        if behavior != behavior(of: newSpread), abs(oldSpread - newSpread) > Constants.minimumBehaviorChangeThreshold {
            return true
        }

        return false
    }
}
