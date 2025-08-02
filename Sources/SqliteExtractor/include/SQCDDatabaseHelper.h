//
//  SQCDDatabaseHelper.h
//  sqlite2coredata
//
//  Created by Tapasya on 27/08/13.
//  Copyright (c) 2013 Tapasya. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQCDTableInfo.h"
#import "SQCDColumnInfo.h"
#import "SQCDForeignKeyInfo.h"
#import "sqlite3.h"
@class SQCDTableInfo,SQCDForeignKeyInfo;

@interface SQCDDatabaseHelper : NSObject

- (NSDictionary<NSString*, SQCDTableInfo*>*) fetchTableInfos:(NSString*) dbPath;
@property (nonatomic, readonly) NSMutableDictionary* manyToManyRelationships;
@property (nonatomic, readonly) NSMutableDictionary*  inverseRelationships;

//+(NSMutableDictionary*) manyToManyRelationships;

-(SQCDForeignKeyInfo*) manyToManyRelationFromTable:(NSString*) fromTableName
                                           toTable:(NSString*) toTableName;


@end
