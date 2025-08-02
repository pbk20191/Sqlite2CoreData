//
//  SQCDTableInfo.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//

import Foundation

//import _SqliteExtractor_constant

public class SQCDTableInfo: NSObject {
    
    @objc public var columns = [String:SQCDColumnInfo]()
    @objc public var sqliteName = ""
    @objc public var sqlStatement = ""
    @objc public var foreignKeys = [String:SQCDForeignKeyInfo]()
    
    @objc public let helper:any SQCDDatabaseHelperProtocol
    
    @objc(initWithHelper:)
    public init(_ helper:any SQCDDatabaseHelperProtocol) {
        self.helper = helper
        super.init()
    }
    
    @objc public func representedClassName() -> String {
        let tableName = sqliteName.lowercased()
        let components = tableName.components(separatedBy: "_")
        var output = ""
        for i in components.indices {
            output += components[i].capitalized
        }
        return output
    }
    
    @objc public func primaryColumn() -> SQCDColumnInfo? {
        for (key, value) in columns {
            if (value.isPrimaryKey) {
                return value
            }
        }
        return nil
    }
    
    @objc public func isManyToMany() -> Bool {
        for (key, value) in columns {
            let foreginKeyInfo = foreignKeys[key]
            
            if let foreginKeyInfo, foreginKeyInfo.toSqliteTableName != sqliteName {
               
            } else {
                // valid column
                return false
            }
        }
        return true
    }
//    
//    -(BOOL) isManyToMany
//    {
//        for (SQCDColumnInfo* colunmInfo in [self.columns allValues]) {
//            SQCDForeignKeyInfo* foreignKeyInfo = [self.foreignKeys valueForKey:colunmInfo.sqliteName];
//            if (!(foreignKeyInfo != nil && ![foreignKeyInfo.toSqliteTableName isEqualToString:self.sqliteName])) {
//                // Found valid column
//                return NO;
//            }
//        }
//        
//        return YES;
//    }

    
    @objc public func xmlRepresentation() -> XMLElement {
        let entity = XMLElement.init(name: "entity")
        entity.addAttribute(.attribute(name: "name", stringValue: self.representedClassName()))
        entity.addAttribute(.attribute(name: "representedClassName", stringValue: self.representedClassName()))
        entity.addAttribute(.attribute(name: "syncable", stringValue: "YES"))
        for (key, value) in columns {
            if let foregin = foreignKeys[value.sqliteName], foregin.toSqliteTableName != sqliteName {
                // TODO Need to findout about the many to many scenario
                entity.addChild(foregin.xmlRepresentation())
                
            } else {
                entity.addChild(value.xmlRepresentation())
            }
        }
        if let inverseRelationForTable = self.helper.inverseRelationships[sqliteName] {
            for inverseInfo in inverseRelationForTable {
                if let manyToMany = self.helper.manyToManyRelationFromTable(sqliteName, toTableName: inverseInfo.toSqliteTableName) {
                    entity.addChild(manyToMany.xmlRepresentation())
                } else if (inverseInfo.toSqliteTableName != inverseInfo.fromSqliteTableName) {
                    entity.addChild(inverseInfo.xmlRepresentation())
                }
            }
        }
        

        return entity
    }
    
//    @objc public func pListRepresentation() -> [String:Any] {
//        
//    }
}

/*
 - (NSDictionary*) pListRepresentation
 {
     NSMutableDictionary* tablePlistDict = [NSMutableDictionary dictionary];
     [tablePlistDict setObject:[self representedClassName] forKey:@"entityName"];
     [tablePlistDict setObject:self.sqliteName forKey:@"tableName"];
     
     NSMutableArray* columnPlist = [NSMutableArray array];
     NSMutableArray* fkplist = [NSMutableArray array];
     NSMutableArray* pkColumnNames = [NSMutableArray array];
     for (SQCDColumnInfo* columnInfo in [self.columns allValues]) {
         SQCDForeignKeyInfo* foreignKeyInfo = [self.foreignKeys valueForKey:columnInfo.sqliteName];
         
         if (foreignKeyInfo != nil && ![foreignKeyInfo.toSqliteTableName isEqualToString:self.sqliteName]) {
             NSMutableDictionary* fkPlistDict = [NSMutableDictionary dictionaryWithDictionary:[foreignKeyInfo pListRepresentation]];
             [fkPlistDict setValue:[NSNumber numberWithBool:(columnInfo.isNonNull==NO)] forKey:@"optional"];
             [fkplist addObject:fkPlistDict];
         } else{
             [columnPlist addObject:[columnInfo pListRepresentation]];
         }
         if (columnInfo.isPrimaryKey) {
             [pkColumnNames addObject:columnInfo.sqliteName];
         }
     }
     
     [tablePlistDict setObject:columnPlist forKey:@"columnmap"];
     [tablePlistDict setObject:pkColumnNames forKey:@"primarykeys"];
     [tablePlistDict setObject:fkplist forKey:@"foreignkeymap"];
     
     NSMutableArray* inverseRelationForTable = [[self.helper inverseRelationships] valueForKey:self.sqliteName];

     for (SQCDForeignKeyInfo* inverseInfo in inverseRelationForTable) {
         if (![inverseInfo.toSqliteTableName isEqualToString:inverseInfo.fromSqliteTableName]) {

         }
     }
     
     return tablePlistDict;
 }
 
 */
