//  Copyright © 2018 JABT. All rights reserved.

import SpriteKit
import GameplayKit


private enum StartingPositionType: UInt32 {
    case top = 0
    case bottom = 1
    case left = 2
    case right = 3

    static var allValues: [StartingPositionType] {
        return [.top, .bottom, .left, .right]
    }
}


class MainScene: SKScene, SKPhysicsContactDelegate {

    var gestureManager: GestureManager!
    private var nodeClusters = Set<NodeCluster>()
    private var lastUpdateTimeInterval: TimeInterval = 0

    private struct Constants {
        static let maximumUpdateDeltaTime: TimeInterval = 1.0 / 60.0
    }


    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        addGestures(to: view)
        setupSystemGesturesForTest(to: view)

        addPhysicsToScene()
        addRecordNodesToScene()

        print("Finished loading all record entities")
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)

        var deltaTime = currentTime - lastUpdateTimeInterval
        deltaTime = deltaTime > Constants.maximumUpdateDeltaTime ? Constants.maximumUpdateDeltaTime : deltaTime
        lastUpdateTimeInterval = currentTime

        EntityManager.instance.update(deltaTime)
        for cluster in nodeClusters {
            cluster.update(deltaTime)
        }

        // keep the nodes facing 0 degrees (i.e. no rotation when affected by physics simulation)
        for case let node as RecordNode in children {
            node.zRotation = 0
        }
    }


    // MARK: SKPhysicsContactDelegate

    func didBegin(_ contact: SKPhysicsContact) {
        // whenever an entity comes into contact with a bounding node, set the contacted entity's hasCollidedWithBoundingNode to true
        if contact.bodyA.node?.name == "boundingNode",
            let contactEntity = contact.bodyB.node?.entity as? RecordEntity,
            !contactEntity.hasCollidedWithBoundingNode,
            contactEntity.intelligenceComponent.stateMachine.currentState is SeekTappedEntityState {
            contactEntity.hasCollidedWithBoundingNode = true
        }

        if let contactEntity = contact.bodyA.node?.entity as? RecordEntity,
            !contactEntity.hasCollidedWithBoundingNode,
            contactEntity.intelligenceComponent.stateMachine.currentState is SeekTappedEntityState,
            contact.bodyB.node?.name == "boundingNode" {
            contactEntity.hasCollidedWithBoundingNode = true
        }
    }


    // MARK: Setup

    private func addGestures(to view: SKView) {
        let tapGesture = TapGestureRecognizer()
        gestureManager.add(tapGesture, to: view)
        tapGesture.gestureUpdated = { [weak self] gesture in
            self?.handleTapGesture(gesture)
        }
    }

    private func setupSystemGesturesForTest(to view: SKView) {
        let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(handleSystemClickGesture(_:)))
        view.addGestureRecognizer(tapGesture)
    }

    private func addPhysicsToScene() {
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        createRepulsiveField()
    }

    private func addRecordNodesToScene() {
        for entity in EntityManager.instance.entities {
            entity.intelligenceComponent.enterInitialState()

            if let recordNode = entity.component(ofType: RenderComponent.self)?.recordNode {
                recordNode.position.x = randomX()
                recordNode.position.y = randomY()
                recordNode.zPosition = 1

                let screenBoundsConstraint = SKConstraint.positionX(SKRange(lowerLimit: 0, upperLimit: frame.width), y: SKRange(lowerLimit: 0, upperLimit: frame.height))
                recordNode.constraints = [screenBoundsConstraint]

                addChild(recordNode)
            }
        }
    }


    // MARK: Gesture Handlers

    private func handleTapGesture(_ gesture: GestureRecognizer) {
        guard let tap = gesture as? TapGestureRecognizer, let position = tap.position else {
            return
        }

        let nodePosition = convertPoint(fromView: position)

        guard let recordNode = nodes(at: nodePosition).first(where: { $0 is RecordNode }) as? RecordNode else {
            return
        }

        print("ID: \(recordNode.record.id)")

        switch tap.state {
        case .ended:
            select(recordNode)
        default:
            return
        }
    }

    @objc
    private func handleSystemClickGesture(_ recognizer: NSClickGestureRecognizer) {
        let clickPosition = recognizer.location(in: recognizer.view)
        let nodePosition = convertPoint(fromView: clickPosition)

        guard let recordNode = nodes(at: nodePosition).first(where: { $0 is RecordNode }) as? RecordNode else {
            return
        }

        print("ID: \(recordNode.record.id) \n Type: \(recordNode.record.type)")

        switch recognizer.state {
        case .ended:
            select(recordNode)
        default:
            return
        }
    }


    // MARK: Helpers

    /// Sets up all the data relationships for the tapped node and starts the physics interactions
    private func select(_ node: RecordNode) {
        guard let entityForNode = node.entity as? RecordEntity else {
            return
        }

        let cluster = nodeCluster(for: entityForNode)
        entityForNode.set(cluster)
        nodeClusters.insert(cluster)

        switch entityForNode.intelligenceComponent.stateMachine.currentState {
        case is SeekTappedEntityState:
            for entity in entityForNode.relatedEntities {
                entity.levelState.previousLevel = entity.levelState.currentLevel
            }

            cluster.didSelect(entityForNode)
            entityForNode.intelligenceComponent.stateMachine.enter(TappedState.self)
        case is WanderState:
            cluster.didSelect(entityForNode)
            entityForNode.intelligenceComponent.stateMachine.enter(TappedState.self)
        default:
            return
        }
    }

    private func nodeCluster(for entity: RecordEntity) -> NodeCluster {
        if let current = entity.cluster {
            return current
        }

        let cluster = NodeCluster(scene: self, entity: entity)
        return cluster
    }

    private func getRandomPosition() -> CGPoint {
        var point = CGPoint.zero

        guard let position = StartingPositionType(rawValue: arc4random_uniform(4)) else {
            return point
        }

        switch position {
        case .top:
            point = CGPoint(x: randomX(), y: size.height - NodeConfiguration.Record.physicsBodyRadius)
            return point
        case .bottom:
            point = CGPoint(x: randomX(), y: NodeConfiguration.Record.physicsBodyRadius)
            return point
        case .left:
            point = CGPoint(x: NodeConfiguration.Record.physicsBodyRadius, y: randomY())
            return point
        case .right:
            point = CGPoint(x: size.width - NodeConfiguration.Record.physicsBodyRadius, y: randomY())
            return point
        }
    }

    private func randomX() -> CGFloat {
        let lowestValue = Int(NodeConfiguration.Record.physicsBodyRadius)
        let highestValue = Int(size.width - NodeConfiguration.Record.physicsBodyRadius)
        return CGFloat(GKRandomDistribution(lowestValue: lowestValue, highestValue: highestValue).nextInt(upperBound: highestValue))
    }

    private func randomY() -> CGFloat {
        let lowestValue = Int(NodeConfiguration.Record.physicsBodyRadius)
        let highestValue = Int(size.height - NodeConfiguration.Record.physicsBodyRadius)
        return CGFloat(GKRandomDistribution(lowestValue: lowestValue, highestValue: highestValue).nextInt(upperBound: highestValue))
    }

    private func addLinearGravityField(to type: StartingPositionType) {
        var vector: vector_float3
        var size: CGSize
        var position: CGPoint

        switch type {
        case .top:
            vector = vector_float3(0, -1, 0)
            size = CGSize(width: frame.width, height: 20)
            position = CGPoint(x: frame.width / 2, y: frame.height - 20)
        case .bottom:
            vector = vector_float3(0, 1, 0)
            size = CGSize(width: frame.width, height: 20)
            position = CGPoint(x: frame.width / 2, y: 20)
        case .left:
            vector = vector_float3(1, 0, 0)
            size = CGSize(width: 20, height: frame.height)
            position = CGPoint(x: 20, y: frame.height / 2)
        case .right:
            vector = vector_float3(-1, 0, 0)
            size = CGSize(width: 20, height: frame.height)
            position = CGPoint(x: frame.width - 20, y: frame.height / 2)
        }

        let field = SKFieldNode.linearGravityField(withVector: vector)
        field.strength = 10
        field.region = SKRegion(size: size)
        field.position = position
        addChild(field)
    }


    // MARK: Debug

    private func createRepulsiveField() {
        let field = SKFieldNode.radialGravityField()
        field.strength = -10
        field.falloff = -0.5
        field.region = SKRegion(radius: 450)
        field.position = CGPoint(x: frame.width / 2 + 5, y: frame.height / 2)
        field.categoryBitMask = 0x1 << 0
        addChild(field)
    }
}
