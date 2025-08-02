//
//  CDMMigrationManager.h
//  CoreDataMigration
//
//  Created by Tapasya on 20/08/13.
//  Copyright (c) 2013 Tapasya. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FMDatabase, SQCDDatabaseHelper;
@interface SQCDMigrationManager : NSObject


@property (nonatomic, strong) NSString* dbPath;
@property (nonatomic, strong) NSDictionary* tableDictionary;
@property (nonatomic, strong) FMDatabase* dataBase;
@property (nonatomic, strong) SQCDDatabaseHelper* helper;

+(BOOL) startDataMigrationWithDBPath:(NSString*) dbPath
                            momdPath:(NSString*) momnPath
                          outputPath:(NSString*) outputPath
                            helper:(SQCDDatabaseHelper*) helper;
@end
