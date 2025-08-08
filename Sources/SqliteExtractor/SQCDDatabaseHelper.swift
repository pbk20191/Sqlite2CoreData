//
//  SQCDDatabaseHelper.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/3/25.
//
import Foundation
import SQLite3
import _SqliteExtractor_constant

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
    
    public func fetchTableInfos(_ dbPath: String) -> [String:SQCDTableInfo]? {
        var _db: OpaquePointer!
    
        let err: CInt = sqlite3_open(dbPath, &_db)

        if err != SQLITE_OK {
            NSLog("error opening!: %d", err)
        } else {
            var statement: OpaquePointer!
            let query = "SELECT name, sql FROM sqlite_master WHERE type=\'table\'"
            let retVal: CInt = sqlite3_prepare_v2(_db, query, -1, &statement, nil)
            var tableInfos = [String:SQCDTableInfo]()

            if retVal == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let tableName = String(cString: sqlite3_column_text(statement, 0) )
                    let tableSql: String! = String(cString: sqlite3_column_text(statement, 1))
                    let tableInfo = SQCDTableInfo(self.linkedChild())

                    tableInfo.sqliteName = tableName
                    tableInfo.sqlStatement = tableSql
                    tableInfo.columns = self.allColumnsInTableNamed(tableInfo.sqliteName, dbPath: dbPath) ?? [:]
                    tableInfo.foreignKeys = self.allForeignKeysInTable(tableInfo, inDatabase: _db)

                    //                // Determine relationship cardinality
                    //                for (SQCDForeignKeyInfo* foreignKeyInfo in [tableInfo.foreignKeys allValues]) {
                    //                    [SQCDDatabaseHelper addInverseRelation:foreignKeyInfo];
                    //                }
                    tableInfos[tableName] = tableInfo
                }
            }

            sqlite3_clear_bindings(statement)

            sqlite3_finalize(statement)

            sqlite3_close(_db)

            self.generateManyToManyInfo(tableInfos)

            return tableInfos
        }

        return nil
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
                    let manyToManyRelation = inverseInfo.copy() as! SQCDForeignKeyInfo

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
    func allForeignKeysInTable(_ tableInfo: SQCDTableInfo, inDatabase db: OpaquePointer) -> [String:SQCDForeignKeyInfo] {
        let uniqColumns = self.allUniqueColumnsInTableNamed(tableInfo.sqliteName, inDatabase: db)
        var statement: OpaquePointer?
        let query: String! = String(format: "pragma foreign_key_list(%@)", tableInfo.sqliteName)
        let retVal: CInt = sqlite3_prepare_v2(db, query, -1, &statement, nil)
        var foreignKeyInfos = [String:SQCDForeignKeyInfo] ()

        if retVal == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let toTableName: String = String(cString: sqlite3_column_text(statement, 2))
                let fromColName: String = String(cString:sqlite3_column_text(statement, 3))
                let toColName: String = String(cString:sqlite3_column_text(statement, 4))
                let onDeleteAction: String = String(cString:sqlite3_column_text(statement, 6))
                let fkInfo = SQCDForeignKeyInfo()

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
        }

        sqlite3_clear_bindings(statement)
        sqlite3_finalize(statement)

        return foreignKeyInfos
    }
    func allColumnsInTableNamed(_ tableName: String!, dbPath: String!) -> [String : SQCDColumnInfo]? {
        // Will return nil if fails, empty dict if no columns
        var _db: OpaquePointer!
        let err: CInt = sqlite3_open(dbPath, &_db)

        if err != SQLITE_OK {
            NSLog("error opening!: %d", err)
        } else {
            var errMsg: UnsafeMutablePointer<CChar>! = nil
            var result: CInt
            var statement: String!

            statement = String(format: "pragma table_info(%@)", tableName)

            var results: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!
            var nRows: CInt = -1
            var nColumns: CInt = -1

            result = sqlite3_get_table(_db, statement, &results, &nRows, &nColumns, &errMsg)

            /* An open database */
            /* SQL to be executed */
            /* Result is in char *[] that this points to */
            /* Number of result rows written here */
            /* Number of result columns written here */
            /* Error msg written here */
            var columnInfos:  [String : SQCDColumnInfo]? = nil

            if !(result == SQLITE_OK) {
                // Invoke the error handler for this class
                //        [self showError:errMsg from:16 code:result] ;
                sqlite3_free(errMsg)
            } else {
                var nameColumnIndex: Int = 0
                var typeColumnIndex: Int = 0
                var nonnullColumnIndex: Int = 0
                var pkColumnIndex: Int = 0
                var j: Int = 0

                while j < nColumns {
                    defer {
                        j += 1
                    }

                    if strcmp(results[j], "name") == 0 {
                        nameColumnIndex = j
                    } else if strcmp(results[j], "type") == 0 {
                        typeColumnIndex = j
                    } else if strcmp(results[j], "pk") == 0 {
                        pkColumnIndex = j
                    } else if strcmp(results[j], "notnull") == 0 {
                        nonnullColumnIndex = j
                    }
                }
                let unwrapped = results!
                if nameColumnIndex < nColumns && typeColumnIndex < nColumns {
                    var i: Int

                    columnInfos = [String : SQCDColumnInfo] ()
                    i = 0

                    while i < nRows {
                        defer {
                            i += 1
                        }

                        var column = SQCDColumnInfo()
                        let  a = results[(i + 1) * Int(nColumns) + nameColumnIndex]
                        
                        column.sqliteName = results[(i + 1) * Int(nColumns) + nameColumnIndex].flatMap { String(cString: $0) } ?? ""
                        column.sqlliteType = results[(i + 1) * Int(nColumns) + typeColumnIndex].flatMap{ String(cString: $0)} ?? ""
                        column.isNonNull = results[(i + 1) * Int(nColumns) + nonnullColumnIndex].flatMap({ String(cString: $0) as NSString
                        })?.boolValue ?? false
                        column.isPrimaryKey = results[(i + 1) * Int(nColumns) + pkColumnIndex].flatMap({
                            String(cString: $0) as NSString
                        })?.boolValue ?? false
                        column.sqliteTableName = tableName

                        // TO DO default value reading
                        columnInfos?[column.sqliteName] = column
                    }
                }
            }

            sqlite3_free_table(results)
            sqlite3_close(_db)


            if columnInfos != nil {
                return columnInfos
            }

        }

        return nil
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
    
    func allUniqueColumnsInTableNamed(_ tableName: String!, inDatabase db: OpaquePointer) -> [String] {
        var idxListStmt: OpaquePointer?
        let query: String! = String(format: "pragma index_list(%@)", tableName)
        let retVal: CInt = sqlite3_prepare_v2(db, query, -1, &idxListStmt, nil)
        var uniqIndexes = [String]()

        if retVal == SQLITE_OK {
            while sqlite3_step(idxListStmt) == SQLITE_ROW {
                let unique = String(cString: sqlite3_column_text(idxListStmt, 2))

                if (unique as NSString).intValue > 0 {
                    let indexName = String(cString: sqlite3_column_text(idxListStmt, 1) )

                    uniqIndexes.append(indexName)
                }
            }
        }

        sqlite3_clear_bindings(idxListStmt)
        sqlite3_finalize(idxListStmt)

        // get the corresponding column names
        var uniqColumns = [String]()

        for indexName in uniqIndexes {
            var colNameStmt: OpaquePointer?
            let query: String! = String(format: "pragma index_info(%@)", indexName)
            let retVal: CInt = sqlite3_prepare_v2(db, query, -1, &colNameStmt, nil)

            if retVal == SQLITE_OK {
                while sqlite3_step(colNameStmt) == SQLITE_ROW {
                    let colName: String = String(cString: sqlite3_column_text(colNameStmt, 2) )

                    uniqColumns.append(colName)
                }
            }

            sqlite3_clear_bindings(colNameStmt)
            sqlite3_finalize(colNameStmt)
        }

        return uniqColumns
    }
}


extension String {
    
    var ns:NSString {
        self as NSString
    }
}
