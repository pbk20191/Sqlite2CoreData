import CoreData
import SqliteExtractor
import _SqliteExtractor_constant
import Foundation
import GRDB

public class SQCDMigrationManager {

    var dbPath = ""
    let dbQueue: DatabaseQueue
    var tableDictionary = [String: SQCDTableInfo]()
    var helper = SQCDDatabaseHelper()


    init(dbPath: String = "", dbQueue: DatabaseQueue, tableDictionary: [String : SQCDTableInfo] = [String: SQCDTableInfo](), helper: SQCDDatabaseHelper = SQCDDatabaseHelper()) {
        self.dbPath = dbPath
        self.dbQueue = dbQueue
        self.tableDictionary = tableDictionary
        self.helper = helper
    }

    public
    static func startDataMigrationWithDBPath(_ dbPath: String!, momdPath momnPath: String!, outputPath: String!, helper: SQCDDatabaseHelper) -> Bool {

        let result = Result {
            var config = GRDB.Configuration()
            config.readonly = true
            config.foreignKeysEnabled = true
            return try DatabaseQueue(path: dbPath, configuration: config)
        }
        guard case let .success(success) = result else {
            NSLog("Failed to open GRDB database at path: \(dbPath)")
            return false
        }
        let manager = SQCDMigrationManager(dbQueue: success)
        manager.helper = helper
        manager.dbPath = dbPath


        do {
            manager.tableDictionary = try manager.helper.fetchTableInfos(dbPath)
        } catch {
            NSLog("Failed to fetch table infos: \(error)")
            return false
        }

        let cdm = SQCDCoreDataManager(withModelPath: momnPath, outputDirectory: outputPath)
        let moc: NSManagedObjectContext! = cdm.managedObjectContext
        do {
            try manager.migrateTableDataFromDatabase(toManagedObjectContext: moc, withRelationships: true)
            return true
        } catch {
            dump(error)
            return false
        }
    }

    func migrateTableDataFromDatabase(toManagedObjectContext moc: NSManagedObjectContext!, withRelationships migrateRelationships: Bool) throws  {
        let tablesDict = self.tableDictionary
        for tableInfo in tablesDict.values {
            let tableName: String! = tableInfo.sqliteName

            try autoreleasepool {
                if tableName != "sqlite_sequence" && !tableInfo.isManyToMany() {
                    NSLog("***************  Started migration for table %@  ****************", tableName)
                    try self.dbQueue.read { db in
                        let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM \(tableName!)")

                        while let row = try cursor.next() {
                            try autoreleasepool {
                                let _ = try self.createEntityFromRow(db, row, withTableInfo: tableInfo, inManagedObjectContext: moc, shouldCreateManyToMany: true)
                                try moc.save()
                            }
                        }
                    }

                    NSLog("***************  Ended migration for table %@  ****************", tableName)
                }
            }
        }
    }

    func createEntityFromRow(_ dataBase:GRDB.Database , _ row: Row, withTableInfo tableInfo: SQCDTableInfo, inManagedObjectContext moc: NSManagedObjectContext!, shouldCreateManyToMany createM2M: Bool) throws -> NSManagedObject? {
        let entityName = tableInfo.representedClassName()
        let primaryProperty = tableInfo.primaryColumn()?.nameForProperty()
        let primaryValue = row[primaryProperty!] as NSNumber? ?? (-1 as NSNumber)

        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        let predicateStr = String(format: "(%@ IN %@)", primaryProperty!, "%@")
        request.predicate = NSPredicate(format: predicateStr, [primaryValue])
        let existing = try moc.fetch(request)
        if existing.count > 0 {
            return existing.first
        }

        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc)

        for columnInfo in tableInfo.columns.values {
            autoreleasepool {
                let foreignKeyInfo = tableInfo.foreignKeys[columnInfo.sqliteName]
                if let foreignKeyInfo, foreignKeyInfo.toSqliteTableName != tableInfo.sqliteName {
                    return
                }

                let propertyName = columnInfo.nameForProperty()
                let propertyType = SQCDTypeMapper.xctypeFromType(columnInfo.sqlliteType)
                let value = self.valueFromRow(row, columnName: columnInfo.sqliteName, propertyType: propertyType)

                entity.setValue(value, forKey: propertyName)
            }
        }

        try self.createRelationshipForEntity(dataBase,entity, inManagedObjectContext: moc, tableInfo: tableInfo, sourceRow: row)
        if createM2M {
            try self.createManyToManyFromEntity(dataBase,entity, withTableInfo: tableInfo, inManagedObjectContext: moc, sourceRow: row)
        }

        return entity
    }

    func createRelationshipForEntity(_ db: GRDB.Database,_ fromEntity: NSManagedObject!, inManagedObjectContext moc: NSManagedObjectContext!, tableInfo: SQCDTableInfo, sourceRow: Row) throws {
        let foreignKeys = tableInfo.foreignKeys.values
        for relationInfo in foreignKeys where relationInfo.toSqliteTableName != tableInfo.sqliteName {
            guard let toTableInfo = tableDictionary[relationInfo.toSqliteTableName] else { continue }
            let fromColumnValue: CInt = sourceRow[relationInfo.fromSqliteColumnName] ?? -1
            let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM \(relationInfo.toSqliteTableName) WHERE \(relationInfo.toSqliteColumnName) = ?", arguments: [fromColumnValue])

            var relatedEntities: [NSManagedObject] = []

            while let result = try cursor.next() {
                if let related = try createEntityFromRow(db, result, withTableInfo: toTableInfo, inManagedObjectContext: moc, shouldCreateManyToMany: true) {
                    relatedEntities.append(related)
                }
            }

            if !relatedEntities.isEmpty {
                if relationInfo.toMany {
                    fromEntity.setValue(NSSet(array: relatedEntities), forKey: relationInfo.relationName)
                } else {
                    fromEntity.setValue(relatedEntities.first, forKey: relationInfo.relationName)
                }
            }
        }
    }

    func createManyToManyFromEntity(_ db:GRDB.Database , _ entity: NSManagedObject!, withTableInfo tableInfo: SQCDTableInfo, inManagedObjectContext moc: NSManagedObjectContext!, sourceRow: Row) throws {
        let primaryProperty = tableInfo.primaryColumn()?.nameForProperty()
        guard let primaryValue = entity.value(forKey: primaryProperty!) as? CInt else { return }

        let inverseDict = tableInfo.helper.inverseRelationships
        let inverseForTable = inverseDict[tableInfo.sqliteName] ?? []

        for inverseInfo in inverseForTable {
            guard let inverseTableInfo = tableDictionary[inverseInfo.toSqliteTableName],
                  inverseTableInfo.isManyToMany(),
                  let m2mInfo = tableInfo.helper.manyToManyRelationFromTable(tableInfo.sqliteName, toTableName: inverseTableInfo.sqliteName),
                  let toTableInfo = tableDictionary[m2mInfo.toSqliteTableName] else { continue }
            let junctionCursor = try Row.fetchCursor(db, sql: "SELECT * FROM \(inverseTableInfo.sqliteName) WHERE \(inverseInfo.toSqliteColumnName) = ?", arguments: [primaryValue])

            var relatedEntities: [NSManagedObject] = []
            while let junctionRow = try junctionCursor.next() {
                guard let destNumber = junctionRow[toTableInfo.primaryColumn()!.sqliteName] as NSNumber? else {
                    NSLog("Warning: No valid destination ID found in junction table for entity: \(entity), table: \(toTableInfo.sqliteName)")
                    assertionFailure()
                    continue
                }
                let destId: CInt = destNumber.int32Value

                let destCursor = try Row.fetchCursor(db, sql: "SELECT * FROM \(toTableInfo.sqliteName) WHERE \(toTableInfo.primaryColumn()!.sqliteName) = ?", arguments: [destId])
                while let destRow = try destCursor.next() {
                    if let related = try createEntityFromRow(db, destRow, withTableInfo: toTableInfo, inManagedObjectContext: moc, shouldCreateManyToMany: false) {
                        relatedEntities.append(related)
                    }
                }
            }

            if relatedEntities.count > 0 {
                entity.setValue(NSSet(array: relatedEntities), forKey: m2mInfo.relationName)
            }
        }
    }

    func valueFromRow(_ row: Row, columnName: String, propertyType: String) -> NSObjectProtocol? {
        var value: NSObjectProtocol?

        switch propertyType {
        case XCSTRING:
            value = row[columnName] as NSString?
        case XCINT32, XCINT64, XCFLOAT , XCINT16, XCDOUBLE:
            if let numbering:NSNumber? = row[columnName]  {
                value = numbering
            }
        case XCDECIMAL:
            if let str: Decimal = row[columnName] {
                value = str as NSDecimalNumber
            }
        case XCDATE:
            value = row[columnName] as NSDate?
        case XCBINARY:
            if let data:Data = row[columnName] {
                value = data as NSData
            }
        case XCBOOL:
            if let boolValue: Bool = row[columnName] {
                value = NSNumber(value: boolValue)
            }
            
        default:
            value = row[columnName] as? NSObjectProtocol
        }

        return value is NSNull ? nil : value
    }
}
