//
//  SQCDDatabaseHelper.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/3/25.
//
import Foundation
import _SqliteExtractor_constant
import GRDB

public class SQCDDatabaseHelper:  SQCDDatabaseHelperProtocol {
    
    
    let store:Store
    
    public init() {
        self.store = Store()
    }
    
    init(_ store:Store) {
        self.store = store
    }
    
    class Store {
        
        public var inverseRelationships:[String:[SQCDForeignKeyInfo]] = [:]
        public var manyToManyRelationships = [String: [String: SQCDForeignKeyInfo]]()
    }
    
    public var inverseRelationships:[String:[SQCDForeignKeyInfo]] {
        get { store.inverseRelationships}
        set { store.inverseRelationships = newValue }
        _modify { yield &store.inverseRelationships }
    }

    public var manyToManyRelationships:[String: [String: SQCDForeignKeyInfo]] {
        get { store.manyToManyRelationships}
        set { store.manyToManyRelationships = newValue }
        _modify { yield &store.manyToManyRelationships }
    }

    func linkedChild() -> SQCDDatabaseHelper {
        let child = SQCDDatabaseHelper(store)

        return child
    }
    
    public func fetchTableInfos(_ dbPath: String) throws -> [String:SQCDTableInfo] {
        let queue = try DatabaseQueue(path: dbPath, configuration: {
            var config = GRDB.Configuration()
            config.readonly = true
            return config
        }())
        var tableInfos = [String:SQCDTableInfo]()
        try queue.read { db in
            
            let query = try db.makeStatement(sql: "SELECT name, sql FROM sqlite_master WHERE type=\'table\'")
            let cursor = try Row.fetchCursor(query)
            while let row = try cursor.next() {
                let tableName:String = row[0]
                let tableSql:String = row[1]
                var tableInfo = SQCDTableInfo(self.linkedChild())
                tableInfo.sqliteName = tableName
                tableInfo.sqlStatement = tableSql
                tableInfo.columns = try self.allColumnsInTableNamed(tableInfo.sqliteName, db: db)
                tableInfo.foreignKeys = try self.allForeignKeysInTable(tableInfo, inDatabase: db)
                tableInfos[tableName] = tableInfo
            }
            self.generateManyToManyInfo(tableInfos)
        }
        return tableInfos
    }
    
    func generateManyToManyInfo(_ tablesDict: [String:SQCDTableInfo]) {
        self.manyToManyRelationships = [:]

        let inverseRelations = self.inverseRelationships.values

        for inverseRelationForTable in inverseRelations {
            for inverseInfo in inverseRelationForTable {
                let sourceTableInfo = tablesDict[inverseInfo.toSqliteTableName]
                
                if let sourceTableInfo, sourceTableInfo.isManyToMany() == true {
                    let foreignKeys = sourceTableInfo.foreignKeys.values
                    let otherForeignKey = (foreignKeys.first?.toSqliteTableName == inverseInfo.fromSqliteTableName) ? foreignKeys.dropFirst().first! : foreignKeys.first!
                    // Add relationship to the actual entity instead of the non existent many to many entity
                    var manyToManyRelation = inverseInfo.copy()

                    manyToManyRelation.isInverse = false
                    manyToManyRelation.toMany = true
                    manyToManyRelation.fromSqliteTableName = inverseInfo.fromSqliteTableName
                    manyToManyRelation.toSqliteTableName = otherForeignKey.toSqliteTableName
                    manyToManyRelation.relationName = manyToManyRelation.toSqliteTableName.underscore().pluralize().camelizeWithLowerFirstLetter()
                    manyToManyRelation.invRelationName = manyToManyRelation.fromSqliteTableName.underscore().pluralize().camelizeWithLowerFirstLetter()
                    manyToManyRelation.isOptional = true

                    self.addManyToManyRelation(manyToManyRelation, forKey: sourceTableInfo.sqliteName)
                }
            }
        }
    }
    func allForeignKeysInTable(_ tableInfo: SQCDTableInfo, inDatabase db: GRDB.Database) throws -> [String:SQCDForeignKeyInfo] {
        let uniqColumns = try self.allUniqueColumnsInTableNamed(tableInfo.sqliteName, inDatabase: db)
        let query: String! = String(format: "pragma foreign_key_list(%@)", tableInfo.sqliteName)
        let statement = try db.makeStatement(sql: query)
        let cursor = try Row.fetchCursor(statement)
        var foreignKeyInfos = [String:SQCDForeignKeyInfo] ()
        
        while let row = try cursor.next() {
            let toTableName: String = row[2]
            let fromColName: String = row[3]
            let toColName: String = row[4]
            let onDeleteAction: String = row[6]
            var fkInfo = SQCDForeignKeyInfo()

            fkInfo.fromSqliteTableName = tableInfo.sqliteName
            fkInfo.toSqliteTableName = toTableName
            fkInfo.fromSqliteColumnName = fromColName
            fkInfo.toSqliteColumnName = toColName
            fkInfo.toMany = false
            fkInfo.relationName = String(toTableName).underscore().camelizeWithLowerFirstLetter()
            fkInfo.sqliteOnDeleteAction = nil
            fkInfo.xcOnDeleteAction = XCNULLIFY

            // if foreign-key column allows null, then the relationship is marked optional
            let fKeyColAllowsNull = tableInfo.columns[fromColName]?.isNonNull == false

            fkInfo.isOptional = fKeyColAllowsNull

            // Build inverse relationship object
            var invFKInfo = SQCDForeignKeyInfo()

            invFKInfo.fromSqliteTableName = fkInfo.toSqliteTableName
            invFKInfo.toSqliteTableName = fkInfo.fromSqliteTableName
            invFKInfo.fromSqliteColumnName = fkInfo.toSqliteColumnName
            invFKInfo.toSqliteColumnName = fkInfo.fromSqliteColumnName
            invFKInfo.toMany = uniqColumns.contains(fkInfo.fromSqliteColumnName) == false

            if invFKInfo.toMany {
                invFKInfo.relationName = invFKInfo.toSqliteTableName.underscore().pluralize().camelizeWithLowerFirstLetter()
            } else {
                invFKInfo.relationName = invFKInfo.toSqliteTableName.underscore().camelizeWithLowerFirstLetter()
            }

            fkInfo.invRelationName = invFKInfo.relationName

            invFKInfo.invRelationName = fkInfo.relationName
            invFKInfo.isInverse = true
            // set the ON DELETE actions for inverse relationship
            invFKInfo.sqliteOnDeleteAction = onDeleteAction

            let capitalizedAction: String! = onDeleteAction.capitalized

            if ["SET NULL", "SET DEFAULT"].contains(capitalizedAction) {
                invFKInfo.xcOnDeleteAction = XCNULLIFY
            } else if capitalizedAction == "RESTRICT" {
                invFKInfo.xcOnDeleteAction = XCDENY
            } else if capitalizedAction == "CASCADE" {
                invFKInfo.xcOnDeleteAction = XCCASCADE
            } else if capitalizedAction == "NO ACTION" {
                invFKInfo.xcOnDeleteAction = (fkInfo.isOptional ? XCNULLIFY : XCDENY)
            } else {
                NSLog("Using \'%@\' as delete rule for unknown sqlite ON DELETE action \'%@\'", XCNOACTION, capitalizedAction)
                invFKInfo.xcOnDeleteAction = XCNOACTION
            }

            // inverse relationships are always optional
            invFKInfo.isOptional = true
            foreignKeyInfos[fkInfo.fromSqliteColumnName] = fkInfo
            self.addInverseRelation(invFKInfo)
        }

        return foreignKeyInfos
    }
    func allColumnsInTableNamed(_ tableName: String, db: GRDB.Database) throws -> [String : SQCDColumnInfo] {
        var columnInfos:  [String : SQCDColumnInfo] = [:]

        for column in try db.columns(in: tableName) {
            var info = SQCDColumnInfo()
            
            info.sqliteName = column.name
            info.sqlliteType = column.type
            info.isNonNull = column.isNotNull
            info.isPrimaryKey = column.primaryKeyIndex != 0
            info.sqliteTableName = tableName

            // TO DO default value reading
            columnInfos[column.name] = info
        }

        return columnInfos
    }
    func addInverseRelation(_ invForeignKeyInfo: SQCDForeignKeyInfo) {
        var inverseRelationForTable = self.inverseRelationships[invForeignKeyInfo.fromSqliteTableName]

        if nil == inverseRelationForTable {
            inverseRelationForTable = []
        }

        inverseRelationForTable!.append(invForeignKeyInfo)
        self.inverseRelationships[invForeignKeyInfo.fromSqliteTableName] = inverseRelationForTable
    }
    
    func addManyToManyRelation(_ manyToManyInfo: SQCDForeignKeyInfo, forKey key: String!) {
        var m2mForTable = self.manyToManyRelationships[manyToManyInfo.fromSqliteTableName]

        if nil == m2mForTable {
            m2mForTable = .init()
        }
        m2mForTable![key] = manyToManyInfo
        self.manyToManyRelationships[manyToManyInfo.fromSqliteTableName] = m2mForTable
    }

    public func manyToManyRelationFromTable(_ fromTableName: String, toTableName: String) -> SQCDForeignKeyInfo? {
        let m2mInfo = self.manyToManyRelationships[fromTableName]
        
        return m2mInfo?[toTableName]
    }
    
    func allUniqueColumnsInTableNamed(_ tableName: String!, inDatabase db: GRDB.Database) throws -> [String] {
        var seen = Set<String>()
         var result: [String] = []

        for idx in try db.indexes(on: tableName) where idx.isUnique {
            for col in idx.columns {        // 각 유니크 인덱스의 모든 컬럼
                if seen.insert(col).inserted {
                    result.append(col)
                }
            }
        }
        return result
    }
}


extension String {
    
    var ns:NSString {
        self as NSString
    }
}
