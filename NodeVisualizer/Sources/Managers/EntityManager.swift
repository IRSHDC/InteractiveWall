//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import SpriteKit
import GameplayKit


/// Class that manages all non-bounding node entities for the scene.
final class EntityManager {
    static let instance = EntityManager()

    /// Set of all entities
    private(set) var entitiesForProxy = [RecordProxy: [RecordEntity]]()

    /// The scene that record nodes are added to
    var scene: MainScene!

    /// List of all GKComponentSystems. The systems will be updated in order. The order is defined to match assumptions made within components.
    private lazy var componentSystems: [GKComponentSystem] = {
        let movementSystem = GKComponentSystem(componentClass: MovementComponent.self)
        let animationSystem = GKComponentSystem(componentClass: AnimationComponent.self)
        let physicsSystem = GKComponentSystem(componentClass: PhysicsComponent.self)
        return [movementSystem, physicsSystem, animationSystem]
    }()

    private struct Constants {
        static let maxRelatedLevel = 4
        static let maxEntitiesPerLevel = 30
    }


    // MARK: Init

    /// Use singleton
    private init() { }


    // MARK: API

    /// Creates and stores record entities from all records from database
    func createEntity(record: RecordDisplayable, levels: RelatedLevels) {
        let entity = RecordEntity(record: record, levels: levels)
        store(entity)
        addComponents(to: entity)
    }

    func allEntities() -> [RecordEntity] {
        return entitiesForProxy.reduce([]) { $0 + $1.value }
    }

    /// If entity is a duplicate it will be removed from the scene, else resets entity.
    func release(_ entity: RecordEntity) {
        guard let entities = entitiesForProxy[entity.record.proxy] else {
            return
        }

        if entities.count > 1 {
            let fade = SKAction.fadeOut(withDuration: style.fadeAnimationDuration)
            entity.perform(action: fade) { [weak self] in
                self?.remove(entity)
            }
        } else {
            entity.reset()
        }
    }

    func requestEntityLevels(for entity: RecordEntity, in cluster: NodeCluster) -> EntityLevels {
        let currentEntities = flatten(cluster.entitiesForLevel).union([cluster.selectedEntity])
        var result = EntityLevels()

        // Build levels for the new entity
        for (index, records) in entity.relatedRecordsForLevel.enumerated() {
            // Prioritize entities that already exist in the cluster
            var entitiesForLevel = entities(for: records, from: currentEntities, size: Constants.maxEntitiesPerLevel)

            // Request the remaining entities up to to allowed size per level
            let remainingSpace = Constants.maxEntitiesPerLevel - entitiesForLevel.count
            let requestedProxies = records.subtracting(proxies(for: entitiesForLevel))
            let requestedEntities = requestEntities(from: requestedProxies, size: remainingSpace, for: cluster)
            entitiesForLevel.formUnion(requestedEntities)

            // Don't insert empty levels
            if entitiesForLevel.isEmpty {
                break
            }
            result.insert(entitiesForLevel, at: index)
        }

        return result
    }

    private func entities(for proxies: Set<RecordProxy>, from entities: Set<RecordEntity>, size: Int) -> Set<RecordEntity> {
        return entities.filter { proxies.contains($0.record.proxy) && entities.count <= size }
    }

    /// Updates all component systems that the EntityManager is responsible for
    func update(_ deltaTime: CFTimeInterval) {
        for componentSystem in componentSystems {
            componentSystem.update(deltaTime: deltaTime)
        }
    }

    /// Adds each entity's components to the component system to allow updates to occur
    func addToComponentSystems(for entities: [RecordEntity]) {
        for entity in entities {
            for componentSystem in componentSystems {
                componentSystem.addComponent(foundIn: entity)
            }
        }
    }

    /// Removes each entity's components from the component system so that unnecessary updates do not happen
    func removeFromComponentSystems(for entities: [RecordEntity]) {
        for entity in entities {
            removeComponents(from: entity)
        }
    }

    /// Dynamically add a new component to an entity
    func add(component: GKComponent, to entity: RecordEntity) {
        entity.addComponent(component)
        addComponents(to: entity)
    }


    // MARK: Helpers

    /// Returns a random subset of entities associated with the given proxies up to a given size, entities in another cluster will be duplicated.
    private func requestEntities(from proxies: Set<RecordProxy>, size: Int, for cluster: NodeCluster) -> Set<RecordEntity> {
        guard let shuffled = GKRandomSource.sharedRandom().arrayByShufflingObjects(in: Array(proxies)) as? [RecordProxy] else {
            return []
        }

        var result = Set<RecordEntity>()
        let max = min(size, shuffled.count)
        for index in (0 ..< max) {
            let proxy = shuffled[index]
            if let entityForProxy = getEntity(for: proxy) {
                if let current = entityForProxy.cluster, current != cluster {
                    let copy = createCopy(of: entityForProxy)
                    copy.cluster = cluster
                    result.insert(copy)
                } else {
                    entityForProxy.cluster = cluster
                    result.insert(entityForProxy)
                }
            }
        }
        return result
    }

    private func store(_ entity: RecordEntity) {
        let proxy = entity.record.proxy
        if entitiesForProxy[proxy] == nil {
            entitiesForProxy[proxy] = [entity]
        } else {
            entitiesForProxy[proxy]!.append(entity)
        }
    }

    /// Removes an entity from the scene and local cache
    private func remove(_ entity: RecordEntity) {
        let proxy = entity.record.proxy
        let entities = entitiesForProxy[proxy]
        if let index = entities?.index(where: { $0 === entity }) {
            removeComponents(from: entity)
            entity.node.removeFromParent()
            entitiesForProxy[proxy]?.remove(at: index)
        }
    }

    /// Returns entity for given record, prioritizing records that are not already clustered
    private func getEntity(for proxy: RecordProxy) -> RecordEntity? {
        guard let entities = entitiesForProxy[proxy] else {
            return nil
        }

        if let unclustered = entities.first(where: { $0.cluster == nil }) {
            return unclustered
        }

        return entities.first
    }

    private func addComponents(to entity: RecordEntity) {
        for componentSystem in componentSystems {
            componentSystem.addComponent(foundIn: entity)
        }
    }

    private func removeComponents(from entity: RecordEntity) {
        for componentSystem in componentSystems {
            componentSystem.removeComponent(foundIn: entity)
        }
    }

    private func flatten(_ levels: EntityLevels) -> Set<RecordEntity> {
        return levels.reduce(Set<RecordEntity>()) { return $0.union($1) }
    }

    private func proxies(for entities: Set<RecordEntity>) -> Set<RecordProxy> {
        let proxies = entities.map { $0.record.proxy }
        return Set(proxies)
    }

    private func createCopy(of entity: RecordEntity) -> RecordEntity {
        let copy = entity.clone()
        store(copy)
        addComponents(to: copy)
        copy.set(position: entity.position)
        copy.node.scale(to: entity.node.size)
        copy.setClonedNodeBitMasks()
        copy.previousCluster = entity.cluster
        scene?.addChild(copy.node)
        return copy
    }
}
