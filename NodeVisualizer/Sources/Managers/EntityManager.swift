//  Copyright © 2018 JABT. All rights reserved.

/*
    Abstract:
    Class that manages all non-bounding node entities for the scene.
 */

import Foundation
import SpriteKit
import GameplayKit


final class EntityManager {

    /// List of all GKComponentSystems. The systems will be updated in order. The order is defined to match assumptions made within components.
    private lazy var componentSystems: [GKComponentSystem] = {
        let intelligenceSystem = GKComponentSystem(componentClass: IntelligenceComponent.self)
        let movementSystem = GKComponentSystem(componentClass: MovementComponent.self)
        let animationSystem = GKComponentSystem(componentClass: AnimationComponent.self)
        let physicsSystem = GKComponentSystem(componentClass: PhysicsComponent.self)
        return [intelligenceSystem, animationSystem, movementSystem, physicsSystem]
    }()

    /// Set of all entities in the scene
    private(set) var entities = Set<GKEntity>()

    /// 2D array of related entities that belong to a particular level
    private(set) var entitiesInLevel = [Set<RecordEntity>]()

    /// Set of all entities in all levels
    private(set) var allLevelEntities = Set<RecordEntity>()

    /// Set of all entities that are currently in a formed state
    private(set) var allEntitiesInFormedState = Set<RecordEntity>()

    /// Local copy of the entities that are associated with the current level
    private var entitiesInCurrentLevel = Set<RecordEntity>()

    private struct Constants {
        static let maxLevel = 5
    }


    private(set) var recordEntities = Set<RecordEntity>()

    /// Dictionary to access a record entity for its RecordDisplayable record identifier
    private var recordEntityForIdentifier = [DataManager.RecordIdentifier: RecordEntity]()

    /// Set of entities that currently belong to a level. Used as a cache check to make sure that levels only contain unique entities to each other
    private var levelledEntities = Set<RecordEntity>()

    /// Dictionary of 2D array of related entities that belong to a particular level for a given record entity
    private(set) var relatedEntitiesForRecordEntity = [RecordEntity: [Set<RecordEntity>]]()



    // MARK: Singleton instance

    private init() { }
    static let instance = EntityManager()


    // MARK: API

    /// Updates all component systems that the EntityManager is responsible for
    func update(_ deltaTime: CFTimeInterval) {
        for componentSystem in componentSystems {
            componentSystem.update(deltaTime: deltaTime)
        }
    }

    /// Adds the entity and all of its components to the appropriate component system
    func add(_ entity: GKEntity) {
        entities.insert(entity)

        for componentSystem in componentSystems {
            componentSystem.addComponent(foundIn: entity)
        }
    }

    /// Removes the entity and all its components from the component system
    func remove(_ entity: GKEntity) {
        entities.remove(entity)
    }

    /// Dynamically add a new component to an entity
    func add(component: GKComponent, to entity: GKEntity) {
        entity.addComponent(component)

        for componentSystem in componentSystems {
            componentSystem.addComponent(foundIn: entity)
        }
    }



    private func add(_ entity: RecordEntity, to identifier: DataManager.RecordIdentifier) {
        if recordEntityForIdentifier[identifier] == nil {
            recordEntityForIdentifier[identifier] = entity
        }
    }

    func createRecordEntities(for records: [RecordDisplayable]) {
        for record in records {
            let identifier = DataManager.RecordIdentifier(id: record.id, type: record.type)
            let recordEntity = RecordEntity(record: record)
            add(recordEntity, to: identifier)
            recordEntities.insert(recordEntity)
        }
    }

    func createRelationshipsForAllEntities() {
        for entity in recordEntities {
            allRelatedEntities(for: [entity])
            relatedEntitiesForRecordEntity[entity] = entitiesInLevel
            entitiesInLevel.removeAll()
            levelledEntities.removeAll()
        }
    }

    private func allRelatedEntities(for entities: Set<RecordEntity>?, toLevel level: Int = 0) {
        guard let entities = entities, !entities.isEmpty else {
            entitiesInLevel = entitiesInLevel.filter { !($0.isEmpty) }
            return
        }

        // reset the previous level entities
        entitiesInCurrentLevel.removeAll()

        // padding for 2D array
        padEntitiesForLevel(level)

        // add the new entities that are about to be related to a level to levelledEntities
        levelledEntities.formUnion(entities)

        for entity in entities {
            // add relatedEntities to the appropriate level
            let relatedEntities = getRelatedEntities(for: entity)
            if !relatedEntities.isEmpty {
                entitiesInLevel[level].formUnion(relatedEntities)
                entitiesInCurrentLevel.formUnion(relatedEntities)
            }
        }

        // all entities that belong past the maxLevel should just go inside maxLevel (i.e. clamp to maxLevel)
        let next = (level == Constants.maxLevel) ? Constants.maxLevel : level + 1

        allRelatedEntities(for: entitiesInCurrentLevel, toLevel: next)
    }




    /// Organizes all related descendant entities to the appropriate hierarchial level
    func associateRelatedEntities(for entities: Set<RecordEntity>?, toLevel level: Int = 0) {
        guard let entities = entities, !entities.isEmpty else {
            entitiesInLevel = entitiesInLevel.filter { !($0.isEmpty) }
            return
        }

        // reset the previous level entities
        entitiesInCurrentLevel.removeAll()

        // padding for 2D array
        padEntitiesForLevel(level)

        // update all level entities set
        allLevelEntities.formUnion(entities)
        allEntitiesInFormedState.formUnion(entities)

        for entity in entities {
            // add relatedEntities to the appropriate level
            let relatedEntities = getRelatedEntities(for: entity)
            if !relatedEntities.isEmpty {
                entitiesInLevel[level].formUnion(relatedEntities)
                entitiesInCurrentLevel.formUnion(relatedEntities)
            }
        }

        // all entities that belong past the maxLevel should just go inside maxLevel (i.e. clamp to maxLevel)
        let next = (level == Constants.maxLevel) ? Constants.maxLevel : level + 1

        associateRelatedEntities(for: entitiesInCurrentLevel, toLevel: next)
    }

    /// Removes all elements in sets associated with leveled entities
    func clearLevelEntities() {
        entitiesInLevel.removeAll()
        allLevelEntities.removeAll()
    }

    /// Resets all entities that are current formed (i.e. that are currently in their levels) to their initial state
    func resetAll() {
        for entity in allLevelEntities {
            entity.reset()
        }

        for entity in allEntitiesInFormedState {
            entity.reset()
        }

        allEntitiesInFormedState.removeAll()
        clearLevelEntities()
    }


    // MARK: Helpers

    private func getRelatedEntities(for entity: RecordEntity) -> [RecordEntity] {
        let record = entity.renderComponent.recordNode.record
        let identifier = DataManager.RecordIdentifier(id: record.id, type: record.type)

        guard let relatedRecords = NodeConfiguration.relatedRecords(for: identifier) else {
            return []
        }

        let relatedEntities = entities(for: relatedRecords)
        return relatedEntities
    }

    private func entities(for records: [RecordDisplayable]) -> [RecordEntity] {
        var recordEntities = [RecordEntity]()

        for record in records {
            if let entity = entity(for: record) {
                recordEntities.append(entity)
            }
        }

        return recordEntities
    }

    private func entity(for record: RecordDisplayable) -> RecordEntity? {
        let identifier = DataManager.RecordIdentifier(id: record.id, type: record.type)

        guard let recordEntity = recordEntityForIdentifier[identifier], !levelledEntities.contains(recordEntity) else {
            return nil
        }

        return recordEntity

//        for entity in entities {
//            if let recordEntity = entity as? RecordEntity,
//                recordEntity.renderComponent.recordNode.record.id == record.id,
//                recordEntity.renderComponent.recordNode.record.type == record.type,
//                !allLevelEntities.contains(recordEntity) {
//                    return recordEntity
//            }
//        }
//
//        return nil
    }

    private func padEntitiesForLevel(_ level: Int) {
        guard entitiesInLevel.count <= level else {
            return
        }

        (entitiesInLevel.count...level).forEach { _ in
            entitiesInLevel.append([])
        }
    }
}
