//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import SpriteKit
import GameplayKit


class MoveComponent: GKAgent2D, GKAgentDelegate {

    init(seek: GKAgent2D) {
        super.init()

        maxSpeed = 500
        maxAcceleration = 100

        delegate = self
        behavior = GKBehavior(goal: GKGoal(toSeekAgent: seek), weight: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    override func update(deltaTime seconds: TimeInterval) {
        super.update(deltaTime: seconds)
    }


    // MARK: GKAgentDelegate

    func agentWillUpdate(_ agent: GKAgent) {
        guard let spriteComponent = entity?.component(ofType: SpriteComponent.self) else {
            return
        }

        position = vector_float2(x: Float(spriteComponent.recordNode.position.x), y: Float(spriteComponent.recordNode.position.y))
    }

    func agentDidUpdate(_ agent: GKAgent) {
        guard let spriteComponent = entity?.component(ofType: SpriteComponent.self) else {
            return
        }

        spriteComponent.recordNode.position = CGPoint(x: CGFloat(position.x), y: CGFloat(position.y))
    }

}





