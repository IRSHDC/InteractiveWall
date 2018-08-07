//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import GameplayKit


final class RecordEntity: GKEntity {

    let record: RecordDisplayable
    let relatedRecordsForLevel: RelatedLevels
    let relatedRecords: Set<RecordProxy>
    var hasCollidedWithBoundingNode = false
    private(set) var clusterLevel: (previousLevel: Int?, currentLevel: Int?) = (nil, nil)

    var cluster: NodeCluster? {
        didSet {
            physicsComponent.cluster = cluster
            movementComponent.cluster = cluster
        }
    }

    var state: GKState? {
        return intelligenceComponent.stateMachine.currentState
    }

    var position: CGPoint {
        return renderComponent.recordNode.position
    }

    var physicsBody: SKPhysicsBody {
        return physicsComponent.physicsBody
    }

    var node: RecordNode {
        return renderComponent.recordNode
    }

    override var description: String {
        return "( [RecordEntity] ID: \(record.id), type: \(record.type), Position: \(position), State: \(String(describing: state)) )"
    }


    // MARK: Components

    private var renderComponent: RenderComponent {
        guard let renderComponent = component(ofType: RenderComponent.self) else {
            fatalError("A RecordEntity must have a RenderComponent")
        }
        return renderComponent
    }

    private var physicsComponent: PhysicsComponent {
        guard let physicsComponent = component(ofType: PhysicsComponent.self) else {
            fatalError("A RecordEntity must have a PhysicsComponent")
        }
        return physicsComponent
    }

    private var movementComponent: MovementComponent {
        guard let movementComponent = component(ofType: MovementComponent.self) else {
            fatalError("A RecordEntity must have a MovementComponent")
        }
        return movementComponent
    }

    private var intelligenceComponent: IntelligenceComponent {
        guard let intelligenceComponent = component(ofType: IntelligenceComponent.self) else {
            fatalError("A RecordEntity must have an IntelligenceComponent")
        }
        return intelligenceComponent
    }

    private var animationComponent: AnimationComponent {
        guard let animationComponent = component(ofType: AnimationComponent.self) else {
            fatalError("A RecordEntity must have an AnimationComponent")
        }
        return animationComponent
    }

    var agent: RecordAgent {
        guard let agent = component(ofType: RecordAgent.self) else {
            fatalError("A RecordEntity must have a GKAgent2D Component")
        }
        return agent
    }


    // MARK: Initializer

    init(record: RecordDisplayable, levels: RelatedLevels) {
        self.record = record
        self.relatedRecordsForLevel = levels
        var relatedRecords = Set<RecordProxy>()
        for level in levels {
            relatedRecords.formUnion(level)
        }
        self.relatedRecords = relatedRecords
        super.init()

        let renderComponent = RenderComponent(record: record)
        let physicsComponent = PhysicsComponent(physicsBody: SKPhysicsBody(circleOfRadius: style.nodePhysicsBodyRadius))
        let movementComponent = MovementComponent()
        let animationComponent = AnimationComponent()
        let intelligenceComponent = IntelligenceComponent(for: self)
        renderComponent.recordNode.physicsBody = physicsComponent.physicsBody
        addComponent(movementComponent)
        addComponent(renderComponent)
        addComponent(physicsComponent)
        addComponent(intelligenceComponent)
        addComponent(animationComponent)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    // MARK: API

    func set(level: Int) {
        clusterLevel = (previousLevel: clusterLevel.currentLevel, currentLevel: level)
        physicsComponent.setLevelInteractingBitMasks(forLevel: level)
    }

    func set(position: CGPoint) {
        renderComponent.recordNode.position = position
    }

    func set(state: EntityState) {
        intelligenceComponent.stateMachine.enter(state.class)
    }

    func set(state: MovementState) {
        movementComponent.requestedMovementState = state
    }

    func set(state: AnimationState) {
        animationComponent.requestedAnimationState = state
    }

    func setBitMasks(forLevel level: Int) {
        physicsComponent.setBitMasks(forLevel: level)
    }

    func updateAgentPositionToMatchNodePosition() {
        agent.position = vector_float2(x: Float(renderComponent.recordNode.position.x), y: Float(renderComponent.recordNode.position.y))
    }

    func run(action: SKAction) {
        renderComponent.recordNode.run(action) { [weak self] in
            self?.renderComponent.recordNode.removeAllActions()
        }
    }

    /// 'Reset' the entity to initial state so that proper animations and movements can take place
    func reset() {
        hasCollidedWithBoundingNode = false
        clusterLevel = (nil, nil)
        cluster = nil
        physicsComponent.reset()
        set(state: .falling)
    }

    func clone() -> RecordEntity {
        return RecordEntity(record: record, levels: relatedRecordsForLevel)
    }

    /// Calculates the distance between self and another entity
    func distance(to entity: RecordEntity) -> CGFloat {
        let dX = entity.renderComponent.recordNode.position.x - renderComponent.recordNode.position.x
        let dY = entity.renderComponent.recordNode.position.y - renderComponent.recordNode.position.y
        return CGFloat(hypotf(Float(dX), Float(dY)))
    }
}
