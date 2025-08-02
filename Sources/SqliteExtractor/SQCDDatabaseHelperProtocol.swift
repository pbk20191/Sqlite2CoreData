//
//  SQCDDatabaseHelperProtocol.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//

import Foundation

@objc public protocol SQCDDatabaseHelperProtocol {
    
    var inverseRelationships:[String:[SQCDForeignKeyInfo]] {
        get
    }
    
    
//    -(SQCDForeignKeyInfo*) manyToManyRelationFromTable:(NSString*) fromTableName
//                                               toTable:(NSString*) toTableName;

    @objc(manyToManyRelationFromTable:toTable:)
    func manyToManyRelationFromTable(_ fromTableName:String,
                                     toTableName:String) -> SQCDForeignKeyInfo? 
    
}
