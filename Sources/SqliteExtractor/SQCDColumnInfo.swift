//
//  SQCDColumnInfo.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
import Foundation

@objcMembers
public class SQCDColumnInfo: NSObject {
    public var sqliteName: String = ""
    public var sqlliteType: String = ""
    public var sqliteDefaultValue: String? = nil
    public var isNonNull = false
    public var isPrimaryKey = false
    public var sqliteTableName: String = ""

    public func nameForProperty() -> String {
    
        var columnName = sqliteName.lowercased()
        if columnName == "id" {
            columnName = sqliteTableName.lowercased() + "_primary_\(sqliteName)"
        }
        let components = columnName.components(separatedBy: "_")
        var buffer = ""
        for i in components.indices {
            if (i == 0) {
                buffer.append(components[i])
            } else {
                buffer.append(components[i].capitalized)
            }
        }
        return buffer
    }

    public func xmlRepresentation() -> XMLElement {
        let childAttr = XMLElement.init(name: "attribute")
        childAttr.addAttribute(.attribute(name: "name", stringValue: self.nameForProperty()))
        childAttr.addAttribute(.attribute(name: "optional", stringValue: self.isNonNull ? "NO" : "YES"))
        childAttr.addAttribute(.attribute(name: "attributeType", stringValue: SQCDTypeMapper.xctypeFromType(self.sqlliteType)))
        childAttr.addAttribute(.attribute(name: "syncable", stringValue: "YES"))
//        [childAttr addAttribute:[NSXMLNode attributeWithName:@"attributeType" stringValue:[SQCDTypeMapper xctypeFromType:self.sqlliteType]]];
        return childAttr
    }

    @objc
    public func pListRepresentation() -> [AnyHashable : Any]? {
        var columnPlistDict: [AnyHashable : Any] = [:]

        columnPlistDict["columnName"] = sqliteName
        columnPlistDict["propertyName"] = nameForProperty()
        columnPlistDict["propertyType"] = SQCDTypeMapper.xctypeFromType(self.sqlliteType)

        return columnPlistDict
    }
}

extension XMLNode {
    
    static func attribute(name:String, stringValue:String) -> XMLNode {
        let node = XMLNode(kind: .attribute)
        node.name = name
        node.stringValue = stringValue
        return node
    }
    
}
