//  Copyright © 2018 JABT. All rights reserved.

import SpriteKit
import GameplayKit


class MainScene: SKScene {

    var gestureManager: NodeGestureManager!
    private var nodeClusters = Set<NodeCluster>()
    private var lastUpdateTimeInterval = 0.0
    private var selectedEntity: RecordEntity?

    private struct Constants {
        static let maximumUpdateDeltaTime = 1.0 / 60.0
        static let windowDisplayOffset: CGFloat = 20
    }

    private struct Keys {
        static let id = "id"
        static let app = "app"
        static let type = "type"
        static let position = "position"
    }


    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        setupSystemGestures()
        addPhysics()
        addEntitiesToScene()
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

        for node in children {
            node.zRotation = 0
        }
    }


    // MARK: API

    func addGestures(to node: SKNode) {
        let tapGesture = TapGestureRecognizer()
        gestureManager.add(tapGesture, to: node)
        tapGesture.gestureUpdated = { [weak self] gesture in
            self?.handleTapGesture(gesture)
        }

        let panGesture = PanGestureRecognizer()
        gestureManager.add(panGesture, to: node)
        panGesture.gestureUpdated = { [weak self] gesture in
            self?.handlePanGesture(gesture)
        }
    }

    func recordNode(at point: CGPoint) -> RecordNode? {
        return nodes(at: point).first { node in
            node is RecordNode && node.contains(point)
        } as? RecordNode
    }


    // MARK: Setup

    private func setupSystemGestures() {
        guard let view = view else {
            return
        }

        let nsTapGesture = NSClickGestureRecognizer(target: self, action: #selector(handleSystemClickGesture(_:)))
        view.addGestureRecognizer(nsTapGesture)

        let nsPanGesture = NSPanGestureRecognizer(target: self, action: #selector(handleSystemPanGesture(_:)))
        view.addGestureRecognizer(nsPanGesture)
    }

    private func addPhysics() {
        physicsWorld.gravity = .zero
    }

    private func addEntitiesToScene() {
        let entities = EntityManager.instance.allEntities()
        let max = frame.width * CGFloat(Configuration.numberOfScreens)
        let spacing = max / CGFloat(entities.count / 2)
        let nodeOffset = style.defaultNodePhysicsBodyRadius / 2

        for (index, entity) in entities.enumerated() {
            let x = spacing * CGFloat(index / 2)
            let y = index % 2 == 0 ? -nodeOffset : frame.height + nodeOffset
            entity.initialPosition = CGPoint(x: x, y: y)
            if let recordNode = entity.component(ofType: RecordRenderComponent.self)?.recordNode {
                recordNode.position = entity.initialPosition
                recordNode.zPosition = 1
                addChild(recordNode)
                addGestures(to: recordNode)
            }
        }
    }


    // MARK: Gesture Handlers

    private func handleTapGesture(_ gesture: GestureRecognizer) {
        guard let tap = gesture as? TapGestureRecognizer, let recordNode = gestureManager.node(for: tap) as? RecordNode, let position = tap.position else {
            return
        }

        switch tap.state {
        case .ended:
            select(recordNode, at: position)
        default:
            return
        }
    }

    private func handlePanGesture(_ gesture: GestureRecognizer) {
        guard let pan = gesture as? PanGestureRecognizer, let node = gestureManager.node(for: pan) as? RecordNode, let entity = node.entity as? RecordEntity, entity.state.pannable else {
            return
        }

        // Ensure that the state for the entity is dragging if the gesture state is not in its recognized state
        if pan.state != .recognized && entity.state != .dragging {
            return
        }

        let deltaX = pan.delta.dx
        let deltaY = pan.delta.dy
        let newX = node.position.x + deltaX
        let newY = node.position.y + deltaY
        let position = CGPoint(x: newX, y: newY)

        switch pan.state {
        case .recognized:
            entity.set(state: .dragging)
            entity.set(position: position)
            if entity.isSelected {
                entity.cluster?.set(position: position)
            }
        case .momentum:
            entity.set(position: position)
            if entity.isSelected {
                entity.cluster?.set(position: position)
            }
        case .possible:
            finishDrag(for: entity)
        default:
            return
        }
    }

    private func finishDrag(for entity: RecordEntity) {
        // Check if entity is controlling a cluster
        if entity.isSelected {
            // Check if entity is still within the frame of the application
            if frame(contains: entity) {
                entity.set(state: .selected)
            } else {
                entity.cluster?.reset()
            }
        } else {
            // If entity was part of a cluster, seek its selected entity
            if let cluster = entity.cluster {
                // Update the entity given the cluster current selected entity
                if let level = cluster.level(for: entity) {
                    entity.hasCollidedWithLayer = false
                    entity.set(level: level)
                    entity.set(state: .seekLevel(level))

                    // If entity was dragged outside of its cluster, duplicate entity with its own cluster
                    if !cluster.intersects(entity) && frame(contains: entity) {
                        let copy = EntityManager.instance.createCopy(of: entity, level: level)
                        createCluster(with: copy)
                    }
                } else {
                    EntityManager.instance.release(entity)
                }
            } else {
                // Create a new cluster from the entity if within application frame
                if frame(contains: entity) {
                    createCluster(with: entity)
                } else {
                    EntityManager.instance.release(entity)
                }
            }
        }
    }

    private func createCluster(with entity: RecordEntity) {
        let cluster = NodeCluster(scene: self, entity: entity)
        nodeClusters.insert(cluster)
        cluster.select(entity)
    }

    @objc
    private func handleSystemClickGesture(_ recognizer: NSClickGestureRecognizer) {
        let clickPosition = recognizer.location(in: recognizer.view)
        let point = convertPoint(fromView: clickPosition)
        guard let node = recordNode(at: point) else {
            return
        }

        switch recognizer.state {
        case .ended:
            select(node, at: point)
        default:
            return
        }
    }

    @objc
    private func handleSystemPanGesture(_ recognizer: NSPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let pannedPosition = recognizer.location(in: recognizer.view)
            let point = convertPoint(fromView: pannedPosition)
            if let recordNode = recordNode(at: point), let entity = recordNode.entity as? RecordEntity, entity.state.pannable {
                selectedEntity = entity
                selectedEntity?.set(state: .dragging)
            }
        case .changed:
            let pannedPosition = recognizer.location(in: recognizer.view)
            let pannedNodePosition = convertPoint(fromView: pannedPosition)

            selectedEntity?.set(position: pannedNodePosition)
            if let entity = selectedEntity, entity.isSelected {
                entity.cluster?.set(position: pannedNodePosition)
            }
        case .ended:
            guard let selectedEntity = selectedEntity else {
                return
            }

            let pannedVelocity = recognizer.velocity(in: recognizer.view)
            let nodePannedVelocity = convertPoint(fromView: pannedVelocity)
            let delta = CGPoint(x: nodePannedVelocity.x * 0.4, y: nodePannedVelocity.y * 0.4)
            let currentPosition = selectedEntity.position
            let newPosition = CGPoint(x: currentPosition.x + delta.x, y: currentPosition.y + delta.y)

            selectedEntity.set(position: newPosition)
            if selectedEntity.isSelected {
                selectedEntity.cluster?.set(position: newPosition)
            }

            if selectedEntity.state == .dragging {
                finishDrag(for: selectedEntity)
                self.selectedEntity = nil
            }
        default:
            return
        }
    }


    // MARK: Helpers

    /// Sets up all the data relationships for the tapped node and starts the physics interactions
    private func select(_ node: RecordNode, at position: CGPoint) {
        guard let entity = node.entity as? RecordEntity, entity.state.tappable, let window = view?.window else {
            return
        }

        let cluster = nodeCluster(for: entity)
        nodeClusters.insert(cluster)

        switch entity.state {
        case .static:
            cluster.select(entity)
        case .seekEntity(_):
            if entity.hasCollidedWithLayer {
                cluster.select(entity)
            }
        case .selected:
            // Only allow actions once the node is aligned with its cluster
            if aligned(entity, with: cluster) {
                if node.openButton(contains: position) {
                    let positionInApplication = position + CGPoint(x: window.frame.minX, y: -Constants.windowDisplayOffset)
                    postRecordNotification(for: entity.record.type, id: entity.record.id, at: positionInApplication)
                } else if node.closeButton(contains: position) {
                    cluster.reset()
                    nodeClusters.remove(cluster)
                }
            }
        default:
            return
        }
    }

    private func nodeCluster(for entity: RecordEntity) -> NodeCluster {
        if let current = entity.cluster {
            return current
        }

        return NodeCluster(scene: self, entity: entity)
    }

    private func frame(contains entity: RecordEntity) -> Bool {
        return entity.node.frame.intersects(frame)
    }

    /// Determines if a given entity is aligned with its cluster
    private func aligned(_ entity: RecordEntity, with cluster: NodeCluster) -> Bool {
        let entityX = Int(entity.position.x)
        let entityY = Int(entity.position.y)
        let clusterX = Int(cluster.center.x)
        let clusterY = Int(cluster.center.y)
        return entityX == clusterX && entityY == clusterY
    }

    private func postRecordNotification(for type: RecordType, id: Int, at position: CGPoint) {
        let info: JSON = [Keys.app: 0, Keys.id: id, Keys.position: position.toJSON(), Keys.type: type.rawValue]
        DistributedNotificationCenter.default().postNotificationName(RecordNotification.display.name, object: nil, userInfo: info, deliverImmediately: true)
    }
}
