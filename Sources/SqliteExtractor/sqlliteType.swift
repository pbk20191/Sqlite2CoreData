//
//  File.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//

import Foundation

import CoreData
import _SqliteExtractor_constant

public class SQCDTypeMapper:NSObject {

    @objc
    public static func string(for attribute: NSAttributeType) ->String {
        switch attribute {
        case .floatAttributeType:
            return XCFLOAT
        case .stringAttributeType:
            return XCSTRING
        case .undefinedAttributeType:
            return XCUNDEFINED
            case .binaryDataAttributeType:
            return XCBINARY
        case .dateAttributeType:
            return XCDATE
        case .transformableAttributeType:
            return XCTRANFORMABLE
        case .integer16AttributeType:
            return XCINT16
        case .integer32AttributeType:
            return XCINT32
        case .integer64AttributeType:
            return XCINT64
        case .decimalAttributeType:
            return XCDECIMAL
        case .doubleAttributeType:
            return XCDOUBLE
        case .booleanAttributeType:
            return XCBOOL
//        case .UUIDAttributeType:
//            <#code#>
//        case .URIAttributeType:
//            <#code#>
//        case .objectIDAttributeType:
//            <#code#>
//        case .compositeAttributeType:
//            <#code#>

        @unknown default:
            return "Undefined"
        
        }
    }

    
    @objc(xctypeFromType:)
    public static func xctypeFromType(_ sqlliteType:String) -> String {
        
        var str = sqlliteType as NSString
        let bracketIndex = str.range(of: "(")
        if bracketIndex.location != NSNotFound {
            str = str.substring(to: bracketIndex.location) as NSString
        }
        
        var attribute:NSAttributeType = .undefinedAttributeType
        switch (str.uppercased as String) {
        case "INT", "MEDIUMINT":
            attribute = .integer32AttributeType
        case "INT8", "UNSIGNED BIG INT", "BIGINT","NUMBER", "INTEGER":
            attribute = .integer64AttributeType
        case "INT2", "TINYINT", "SMALLINT":
            attribute = .integer16AttributeType
            
        case "CHARACTER", "CHAR", "VARCHAR", "VARYING CHARACTER", "NCHAR", "NATIVE CHARACTER", "NVARCHAR", "NVARCHAR2", "TEXT", "CLOB", "STRING":
            attribute = .stringAttributeType
            
        case "BLOB", "BINARY":
            attribute = .binaryDataAttributeType
            
        case "REAL", "DOUBLE", "DOUBLE PRECISION":
            attribute = .doubleAttributeType
            
            
        case "DECIMAL", "NUMERIC":
            attribute = .decimalAttributeType
            
        case "FLOAT":
            attribute = .floatAttributeType
            
        case "DATE", "DATETIME", "TIMESTAMP":
            attribute = .dateAttributeType
            
        case "BOOL", "BOOLEAN":
            attribute = .booleanAttributeType
            
        default:
            NSLog("Warning: using undefined for sqlite type \(str)")
            attribute = .undefinedAttributeType
        }

        return Self.string(for: attribute)
    }
    
    
}
