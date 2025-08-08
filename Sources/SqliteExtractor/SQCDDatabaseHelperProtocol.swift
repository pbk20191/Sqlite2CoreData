//
//  SQCDDatabaseHelperProtocol.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//

import Foundation

public protocol SQCDDatabaseHelperProtocol:AnyObject {
    
    var inverseRelationships:[String:[SQCDForeignKeyInfo]] {
        get
    }
    
    
//    -(SQCDForeignKeyInfo*) manyToManyRelationFromTable:(NSString*) fromTableName
//                                               toTable:(NSString*) toTableName;

    func manyToManyRelationFromTable(_ fromTableName:String,
                                     toTableName:String) -> SQCDForeignKeyInfo? 
    
}
