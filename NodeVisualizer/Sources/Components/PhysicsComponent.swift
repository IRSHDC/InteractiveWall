//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import SpriteKit
import GameplayKit


/// A `GKComponent` that provides an `SKPhysicsBody` for an entity. This enables the entity to be represented in the SpriteKit physics world.
class PhysicsComponent: GKComponent {

    private(set) var physicsBody: SKPhysicsBody

    private struct BitMasks {
        let categoryBitMask: UInt32
        let collisionBitMask: UInt32
        let contactTestBitMask: UInt32
    }


    // MARK: Initializer

    init(physicsBody: SKPhysicsBody) {
        self.physicsBody = physicsBody
        super.init()
        setupInitialPhysicsBodyProperties()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    // MARK: Lifecycle

    override func update(deltaTime seconds: TimeInterval) {
        super.update(deltaTime: seconds)
        guard let entity = entity as? RecordEntity else {
            return
        }

        if let cluster = entity.cluster, cluster.selectedEntity.state == .panning {
            return
        }

        // need to check if the contactedBodies belong to the same level


        let contactedBodies = physicsBody.allContactedBodies()
        for contactedBody in contactedBodies {
            guard let contactedEntity = contactedBody.node?.entity as? RecordEntity else {
                continue
            }

            if contactedEntity.hasCollidedWithBoundingNode && !entity.hasCollidedWithBoundingNode {
                entity.hasCollidedWithBoundingNode = true
                return
            }
        }
    }


    // MARK: API

    /// Sets the entity's bitMasks to interact with entities within its own level as well as its bounding node
    func setInteractingBitMasks(forLevel level: Int) {
        guard let entity = entity as? RecordEntity, let boundingNode = entity.cluster?.layerForLevel[level]?.nodeBoundingRenderComponent.node, let boundingNodePhysicsBody = boundingNode.physicsBody else {
            return
        }

        let levelBitMasks = bitMasks(forLevel: level)
        physicsBody.categoryBitMask = levelBitMasks.categoryBitMask | boundingNodePhysicsBody.categoryBitMask
        physicsBody.collisionBitMask = levelBitMasks.collisionBitMask | boundingNodePhysicsBody.collisionBitMask
        physicsBody.contactTestBitMask = levelBitMasks.contactTestBitMask | boundingNodePhysicsBody.contactTestBitMask
    }

    /// Sets the entity's bitMask to only interact with entities within its own level
    func setRecordNodeLevelInteractingBitMasks(forLevel level: Int) {
        let levelBitMasks = bitMasks(forLevel: level)
        physicsBody.categoryBitMask = levelBitMasks.categoryBitMask
        physicsBody.collisionBitMask = levelBitMasks.collisionBitMask
        physicsBody.contactTestBitMask = levelBitMasks.contactTestBitMask
    }

    /// Reset the entity's physics body to its initial state
    func reset() {
        // semi non-sticky collisions
        physicsBody.restitution = 0.5
        physicsBody.friction = 0.5
        physicsBody.linearDamping = 0.5

        // interactable with rest of physics world
        physicsBody.isDynamic = true

        // set bitMasks to interact with all entities
        resetBitMasks()
    }


    // MARK: Helpers

    private func setupInitialPhysicsBodyProperties() {
        physicsBody.friction = 0
        physicsBody.restitution = 0
        physicsBody.linearDamping = 0
        physicsBody.mass = style.nodePhysicsBodyMass
    }

    /// Returns the bitMasks for the entity's level
    private func bitMasks(forLevel level: Int) -> BitMasks {
        let levelBit = level + 1
        let categoryBitMask: UInt32 = 0x1 << levelBit
        let collisionBitMask: UInt32 = 0x1 << levelBit
        let contactTestBitMask: UInt32 = 0x1 << levelBit

        return BitMasks(
            categoryBitMask: categoryBitMask,
            collisionBitMask: collisionBitMask,
            contactTestBitMask: contactTestBitMask
        )
    }

    /// Resets the entity's bitMask to be able to interact with all entities
    private func resetBitMasks() {
        physicsBody.categoryBitMask = 0xFFFFFFFF
        physicsBody.collisionBitMask = 0xFFFFFFFF
        physicsBody.contactTestBitMask = 0xFFFFFFFF
    }
}
