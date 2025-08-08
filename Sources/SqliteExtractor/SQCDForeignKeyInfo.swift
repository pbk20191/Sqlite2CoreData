//
//  SQCDForeignKeyInfo.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//

import Foundation

public struct SQCDForeignKeyInfo {
    
    public var fromSqliteTableName = ""
    public var toSqliteTableName = ""
    public var fromSqliteColumnName = ""
    public var toSqliteColumnName = ""
    public var relationName = ""
    public var invRelationName = ""
    public var toMany = false
    public var isInverse = false
    public var isOptional = false
    public var sqliteOnDeleteAction = String?.none
    public var xcOnDeleteAction = ""

    public func nameForProperty(_ property:String) -> String {
        var columnName = property.lowercased()
        let components = columnName.components(separatedBy: "_")
        var output = ""
        for i in components.indices {
            if (i==0) {
                output += components[i]
            } else {
                output += components[i].capitalized
            }
        }
        return output
    }
    
    public func xmlRepresentation() -> XMLElement {
        let childAttr = XMLElement.init(name: "relationship")
        childAttr.addAttribute(.attribute(name: "name", stringValue: relationName))
        childAttr.addAttribute(.attribute(name: "destinationEntity", stringValue: toSqliteTableName.capitalized))
        childAttr.addAttribute(.attribute(name: "inverseName", stringValue: invRelationName))
        childAttr.addAttribute(.attribute(name: "inverseEntity", stringValue: toSqliteTableName.capitalized))
        childAttr.addAttribute(.attribute(name: "toMany", stringValue: toMany ? "YES" : "NO"))
        childAttr.addAttribute(.attribute(name: "deletionRule", stringValue: xcOnDeleteAction))
        childAttr.addAttribute(.attribute(name: "syncable", stringValue: "YES"))
        childAttr.addAttribute(.attribute(name: "minCount", stringValue: isOptional ? "0" : "1"))
        if (!self.toMany) {
            childAttr.addAttribute(.attribute(name: "maxCount", stringValue: "1"))
        }
        childAttr.addAttribute(.attribute(name: "optional", stringValue: isOptional ? "YES" : "NO"))
        return childAttr
        
    }
    
    public func copy(with zone: NSZone? = nil) -> SQCDForeignKeyInfo {
        var copy = SQCDForeignKeyInfo()
        copy.fromSqliteTableName = self.fromSqliteTableName
        copy.toSqliteTableName = self.toSqliteTableName
        copy.relationName = relationName
        copy.invRelationName = invRelationName
        copy.toMany = toMany
        copy.isInverse = isInverse
//        copy.isOptional = isOptional
//        copy.sqliteOnDeleteAction = sqliteOnDeleteAction
//        copy.xcOnDeleteAction = xcOnDeleteAction
        return copy
    }
    
    public func pListRepresentation() -> [String:Any] {
        var relationPlistDict = [String:Any]()
        relationPlistDict["fromEntityName"] = fromSqliteTableName.capitalized
        relationPlistDict["toEntityName"] = toSqliteTableName.capitalized
        relationPlistDict["relationName"] = relationName
        relationPlistDict["inverseRelationName"] = invRelationName
        relationPlistDict["fromTableName"] = fromSqliteTableName
        relationPlistDict["toTableName"] = toSqliteTableName
        relationPlistDict["fromColumnName"] = fromSqliteColumnName
        relationPlistDict["toColumnName"] = toSqliteColumnName
        relationPlistDict["fromPropertyName"] = fromSqliteColumnName
        relationPlistDict["toPropertyName"] = toSqliteColumnName
        relationPlistDict["isToMany"] = toMany ? "YES" : "NO"
        return relationPlistDict
    }
    
}
