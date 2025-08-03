import CoreData
import SqliteExtractor
import FMDB
import _SqliteExtractor_constant
// Preprocessor directives found in file:
// #import "SQCDMigrationManager.h"
// #import <CoreData/CoreData.h>
// #import "_SqliteExtractor_constant.h"
// #pragma mark - Migration
// #pragma mark - data and relationship migration
// #pragma mark - NSManagedObject Creation
// #pragma mark - DB helpers
//
//  CDMMigrationManager.m
//  CoreDataMigration
//
//  Created by Tapasya on 20/08/13.
//  Copyright (c) 2013 Tapasya. All rights reserved.
//
//@import SQCDDatabaseHelper;

extension FMDatabase {
    
    @NSManaged func intForQuery(_ str:String) -> CInt
}

public class SQCDMigrationManager:NSObject {
    
    var dbPath = ""
    var tableDictionary = [String:SQCDTableInfo]()
    var dataBase:FMDatabase? = nil
    var helper = SQCDDatabaseHelper()
    


    deinit {
        self.dataBase?.close()
        self.dataBase = nil
    }

    @objc public
    static func startDataMigrationWithDBPath(_ dbPath: String!, momdPath momnPath: String!, outputPath: String!, helper: SQCDDatabaseHelper) -> Bool {
        let manager = SQCDMigrationManager()
        manager.helper = helper
        manager.dbPath = dbPath

        let database = manager.openDatabase()!

        manager.tableDictionary = manager.helper.fetchTableInfos(dbPath) ?? [:]

        let cdm = SQCDCoreDataManager(withModelPath: momnPath, outputDirectory: outputPath)
        let moc: NSManagedObjectContext! = cdm.managedObjectContext

        
        return manager.migrateTableDataFromDatabase(database, toManagedObjectContext: moc, withRelationships: true)

    }
    func migrateTableDataFromDatabase(_ database: FMDatabase, toManagedObjectContext moc: NSManagedObjectContext!, withRelationships migrateRelationships: Bool) -> Bool {
        let tablesDict = self.tableDictionary
        var error: Error?

        for tableInfo in tablesDict.values {
            let tableName: String! = tableInfo.sqliteName

            autoreleasepool { () -> Void in
                if tableName != "sqlite_sequence" && !tableInfo.isManyToMany() {
                    NSLog("***************  Started migration for table %@  ****************", tableInfo.sqliteName)
                    let results = database.executeQuery(String(format: "select * from %@", tableName), withArgumentsIn: [])!

                    while results.next() {
                        autoreleasepool { () -> Void in
                            let entity = self.createEntityFromResultSet(results, withTableInfo: tableInfo, inManagedObjectContext: moc, shouldCreateManyToMany: true)

                            do {
                                try moc.save()

                            } catch  let error as NSError {
                                NSLog("Error while saving \(entity?.entity.name) \(error.localizedDescription)")

                                for detailedError in error.userInfo[NSDetailedErrorsKey] as! NSArray{
                                    NSLog("Error while saving \(detailedError)")
                                }
                            }
                        }
                    }

                    NSLog("***************  Ended migration for table %@  ****************", tableInfo.sqliteName)
                }
            }
        }

        return error != nil
    }
    func fetchEntity(_ entityName: String!, primaryPropertyName propertyName: String!, primaryPropertyValue primaryId: CInt, inManagedObjectContext moc: NSManagedObjectContext!) -> [NSManagedObject]? {
        let request = NSFetchRequest<NSManagedObject>.init(entityName: entityName)
    
        let description = NSEntityDescription.entity(forEntityName: entityName, in: moc)
        request.entity = description
        let predicateStr = String(format: "(%@ IN %@)", propertyName, "%@")
        request.predicate = .init(format: predicateStr, [primaryId as NSNumber])
        do {
            return try moc.fetch(request)
            
        } catch {
            assertionFailure(error.localizedDescription)
            return nil
        }
    }
    func createEntityFromResultSet(_ results: FMResultSet, withTableInfo tableInfo: SQCDTableInfo, inManagedObjectContext moc: NSManagedObjectContext!, shouldCreateManyToMany createM2M: Bool) -> NSManagedObject? {
        let entityName: String! = tableInfo.representedClassName()
        let primaryProperty: String! = tableInfo.primaryColumn()?.nameForProperty()
        let existingEntities = self.fetchEntity(entityName, primaryPropertyName: primaryProperty, primaryPropertyValue: results.int(forColumn: primaryProperty), inManagedObjectContext: moc)

        if (existingEntities?.count ?? 0) > 0 {
            NSLog("Found Entity %@", entityName)

            return existingEntities?.first
        }

        NSLog("Creating Entity %@", entityName)
        
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc)

        for columnInfo in tableInfo.columns.values {
            autoreleasepool { () -> Void in
                let foreignKeyInfo = tableInfo.foreignKeys[columnInfo.sqliteName]

                if let foreignKeyInfo, foreignKeyInfo.toSqliteTableName != tableInfo.sqliteName {
                    NSLog("Ingnoring foreignkey %@ from %@ to %@", foreignKeyInfo.fromSqliteColumnName, foreignKeyInfo.fromSqliteTableName, foreignKeyInfo.toSqliteTableName)
                } else {
                    let propertyName: String! = columnInfo.nameForProperty()
                    let propertyType: String! = SQCDTypeMapper.xctypeFromType(columnInfo.sqlliteType)
                    let value = self.valueFromResultSet(results, forColumnName: columnInfo.sqliteName, propertyType: propertyType)

                    entity.setValue(value, forKey: propertyName)
                }
            }
        }

        if entity != nil {
            autoreleasepool { () -> Void in
                self.createRelationshipForEntity(entity, inManagedObjectContext: moc, tableInfo: tableInfo, resultSet: results)
            }

            if createM2M {
                autoreleasepool { () -> Void in
                    self.createManyToManyFromEntity(entity, withTableInfo: tableInfo, inManagedObjectContext: moc)
                }
            }
        }

        return entity
    }
    func createManyToManyFromEntity(_ entity: NSManagedObject!, withTableInfo tableInfo: SQCDTableInfo, inManagedObjectContext moc: NSManagedObjectContext!) {
        let database = self.openDatabase()!
        let primaryProperty = tableInfo.primaryColumn()?.nameForProperty()
        let tablesDict = self.tableDictionary
        let inverseDict = tableInfo.helper.inverseRelationships
        let inverseForTable = inverseDict[tableInfo.sqliteName]

        for inverseInfo in (inverseForTable ?? []) {
            let inverseSourceTableInfo = tablesDict[inverseInfo.toSqliteTableName]

            if let inverseSourceTableInfo, inverseSourceTableInfo.isManyToMany() {
                // TODO migrate many to many
                let m2mInfo = tableInfo.helper.manyToManyRelationFromTable(tableInfo.sqliteName, toTableName: inverseSourceTableInfo.sqliteName)
                // Fetch results from db and create entities
                
//                NSNumber.intValue
//                NSString.intValue
                let fromColunmValue: CInt = primaryProperty.flatMap{
                    let value = entity.value(forKey: $0)
                    if let string = value as? NSString {
                        return string.intValue
                    } else if let number = value as? NSNumber {
                        return number.int32Value
                    }
                    return nil
                } ?? -1
                let resultSet = database.executeQuery(String(format: "select * from %@ where %@=%d", inverseSourceTableInfo.sqliteName, inverseInfo.toSqliteColumnName, fromColunmValue), withArgumentsIn: [])
                
            
                let count = database.intForQuery(String(format: "select count(%@) from %@ where %@=%d", inverseInfo.toSqliteColumnName, inverseSourceTableInfo.sqliteName, inverseInfo.toSqliteColumnName, fromColunmValue))
                var relationEntities = [NSManagedObject]()
                let toTableInfo = tablesDict[m2mInfo!.toSqliteTableName]

                autoreleasepool { () -> Void in
                    while resultSet?.next() == true {
//                        resultSet?.int(forColumn: <#T##String#>)
                        let destValue: CInt = resultSet?.int(forColumn: toTableInfo!.primaryColumn()!.sqliteName) ?? -1
                        let destResults = database.executeQuery(String(format: "select * from %@ where %@=%d ", toTableInfo!.sqliteName, toTableInfo!.primaryColumn()!.sqliteName, destValue), withArgumentsIn: [])

                        while destResults?.next() == true {
                            let relationEntity = self.createEntityFromResultSet(destResults!, withTableInfo: toTableInfo!, inManagedObjectContext: moc, shouldCreateManyToMany: false)

                            if let relationEntity = relationEntity {
                                relationEntities.append(relationEntity)
                            }
                        }
                    }
                }
                if let m2mInfo {
                    NSLog("Creating Relation \(m2mInfo.relationName) form \(m2mInfo.fromSqliteTableName) to \(m2mInfo.toSqliteTableName)");
                    if (relationEntities.count == count) {
                        entity.setValue(NSSet(array: relationEntities), forKey: m2mInfo.relationName)
                    }
                } else {
                    preconditionFailure("m2mInfo is null")
                }
            }
        }
    }
    func createRelationshipForEntity(_ fromEntity: NSManagedObject!, inManagedObjectContext moc: NSManagedObjectContext!, tableInfo: SQCDTableInfo, resultSet fromResultSet: FMResultSet) {
        let database = self.openDatabase()!
        // Fetch all the related entries from the destination table
        let foreignKeyInfo = tableInfo.foreignKeys.values

        // Iterate over all foreign keys
        for relationInfo in tableInfo.foreignKeys.values {
            if relationInfo.toSqliteTableName != tableInfo.sqliteName {
                // Get the destination table info
                let tablesDict = self.tableDictionary
                let toTableInfo = tablesDict[relationInfo.toSqliteTableName]!
                // Fetch results from db and create entities
                let fromColumnValue: CInt = fromResultSet.int(forColumn:relationInfo.fromSqliteColumnName)
                let results = database.executeQuery(String(format: "select * from %@ where %@=%d", relationInfo.toSqliteTableName, relationInfo.toSqliteColumnName, fromColumnValue), withArgumentsIn: [])
                var relationEntities = [NSManagedObject]()

                while results?.next() == true {
                    NSLog("Creating Relation \(relationInfo.relationName) form \(fromEntity.entity.name) to \(relationInfo.toSqliteTableName.capitalized)")

                    let relationEntity = self.createEntityFromResultSet(results!, withTableInfo: toTableInfo, inManagedObjectContext: moc, shouldCreateManyToMany: true)

                    if let relationEntity = relationEntity {
                        relationEntities.append(relationEntity)
                    }
                }

                if (!relationEntities.isEmpty) {
                    if relationInfo.toMany {
                        fromEntity.setValue(NSSet(array: relationEntities), forKey: relationInfo.relationName)
                    } else {
                        fromEntity.setValue(relationEntities[0], forKey: relationInfo.relationName)
                    }
                }
            }
        }
    }
    func valueFromResultSet(_ results: FMResultSet, forColumnName columnName: String!, propertyType: String!) -> NSObjectProtocol? {
        var value: NSObjectProtocol? = nil

        // TODO handle other values
        if propertyType == XCSTRING {
            value = results.string(forColumn: columnName) as NSString?
        } else if propertyType == XCINT32 || propertyType == XCINT64 {
            value = results.int(forColumn: columnName) as NSNumber
        } else if propertyType == XCDECIMAL {
            value = results.string(forColumn: columnName).flatMap{
                Decimal(($0 as NSString).doubleValue) as NSDecimalNumber
            }
        } else if propertyType == XCDATE {
            value = results.date(forColumn: columnName) as NSDate?
        } else {
            value = results.object(forColumnName: columnName) as! (any NSObjectProtocol)?
        }

        if value?.isKind(of: NSNull.self) == true {
            value = nil
        }

        return value
    }
    func openDatabase() -> FMDatabase? {
        if let dataBase = self.dataBase {
            return dataBase
        }

        self.dataBase = FMDatabase(path: self.dbPath)

        if self.dataBase?.open() != true {
            self.dataBase = nil
            NSLog("Failed to open database!")
        }

        return self.dataBase
    }
}
