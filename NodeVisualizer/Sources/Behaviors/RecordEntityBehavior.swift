//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import GameplayKit


/// 'RecordEntityBehavior' is a `GKBehavior` subclass that provides factory methods to create goals and behaviors for different mandates.
class RecordEntityBehavior: GKBehavior {

    static func behaviorToAvoidObstacles(withRadius radius: CGFloat, position: CGPoint) -> GKBehavior {
        let behavior = RecordEntityBehavior()
        let obstacle = GKCircleObstacle(radius: Float(radius))

        let position = vector_float2(x: Float(position.x), y: Float(position.y))
        obstacle.position = position

        let avoidObstaclesGoal = GKGoal(toAvoid: [obstacle], maxPredictionTime: 10.0)
        behavior.setWeight(100, for: avoidObstaclesGoal)
        return behavior
    }

    static func behavior(toSeek agent: GKAgent2D) -> GKBehavior {
        let behavior = RecordEntityBehavior()
        behavior.setWeight(1, for: GKGoal(toSeekAgent: agent))
        return behavior
    }

    static func behavior(agentsToSeparateFrom: [GKAgent2D]) -> GKBehavior {
        let behavior = RecordEntityBehavior()
        behavior.setWeight(2, for: GKGoal(toSeparateFrom: agentsToSeparateFrom, maxDistance: 50, maxAngle: 2 * .pi))
        return behavior
    }

    static func behavior(seek: GKAgent2D, agentsToSeparateFrom: [GKAgent2D]) -> GKBehavior {
        let behavior = RecordEntityBehavior()
        behavior.setWeight(0.5, for: GKGoal(toSeekAgent: seek))
        behavior.setWeight(2, for: GKGoal(toSeparateFrom: agentsToSeparateFrom, maxDistance: 50, maxAngle: 2 * .pi))
        return behavior
    }

    static func stop() -> GKBehavior {
        let behavior = RecordEntityBehavior()
        behavior.setWeight(1, for: GKGoal(toReachTargetSpeed: 0))
        return behavior
    }

    static func behavior(toSeek agent: GKAgent2D, withTargetSpeed speed: Float) -> GKBehavior {
        let behavior = RecordEntityBehavior()
        behavior.setWeight(2, for: GKGoal(toSeekAgent: agent))
        behavior.setWeight(1, for: GKGoal(toReachTargetSpeed: speed))
        return behavior
    }

    static func avoid(agent: GKAgent2D) -> GKBehavior {
        let behavior = RecordEntityBehavior()
        behavior.setWeight(1, for: GKGoal(toAvoid: [agent], maxPredictionTime: 10))
        return behavior
    }
}
