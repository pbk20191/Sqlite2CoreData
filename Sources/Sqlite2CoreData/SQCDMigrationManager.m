//
//  CDMMigrationManager.m
//  CoreDataMigration
//
//  Created by Tapasya on 20/08/13.
//  Copyright (c) 2013 Tapasya. All rights reserved.
//

#import "SQCDMigrationManager.h"
@import FMDB;
@import SQCDHelper;
#import <CoreData/CoreData.h>
#import "SqliteExtractor.h"



@implementation SQCDMigrationManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        self->_dbPath = nil;
        self->_tableDictionary = nil;
    }
    return self;
}

-(void)dealloc {
    if (self.dataBase) {
        [self.dataBase close];
    }
}

#pragma mark - Migration

+(BOOL) startDataMigrationWithDBPath:(NSString*) dbPath
                            momdPath:(NSString*) momnPath
                          outputPath:(NSString*) outputPath
                              helper:(SQCDDatabaseHelper*) helper
{
    SQCDMigrationManager* manager = SQCDMigrationManager.new;
    manager.helper = helper;
    manager.dbPath = dbPath;

    
    FMDatabase* database = [manager openDatabase];
    manager.tableDictionary = [manager.helper fetchTableInfos:dbPath];
    SQCDCoreDataManager* cdm = [[SQCDCoreDataManager alloc] initWithModelPath:momnPath outputDirectory:outputPath];
    NSManagedObjectContext* moc = [cdm managedObjectContext];
    
    [manager migrateTableDataFromDatabase:database
                               toManagedObjectContext:moc
                                    withRelationships:YES];
    
    return YES;
}

#pragma mark - data and relationship migration

- (BOOL) migrateTableDataFromDatabase:(FMDatabase*) database
               toManagedObjectContext:(NSManagedObjectContext*) moc
                    withRelationships:(BOOL) migrateRelationships
{
    NSDictionary *tablesDict = [self tableDictionary];
    __block __weak NSError* error;
    
    for (SQCDTableInfo* tableInfo in [tablesDict allValues]) {
        NSString* tableName =  tableInfo.sqliteName;
        
        @autoreleasepool {
            if (![tableName isEqualToString:@"sqlite_sequence"] && ![tableInfo isManyToMany]){
                
                NSLog(@"***************  Started migration for table %@  ****************", tableInfo.sqliteName);
                
                FMResultSet *results = [database executeQuery:[NSString stringWithFormat:@"select * from %@", tableName]];
                while([results next]) {
                    @autoreleasepool {
                        NSManagedObject *entity =  [self createEntityFromResultSet:results
                                                                                    withTableInfo:tableInfo
                                                                           inManagedObjectContext:moc
                                                                            shouldCreateManyToMany:YES];
                        [moc save:&error];
                        if ( nil != error){
                            NSLog(@"Error while saving %@, %@", entity.entity.name, [error localizedDescription]);
                            for (NSError* detailedError in [[error userInfo] valueForKey:NSDetailedErrorsKey]) {
                                NSLog(@"Error while saving %@", [detailedError debugDescription]);
                            }
                        }

                    }
                }
                NSLog(@"***************  Ended migration for table %@  ****************", tableInfo.sqliteName);
            }
        }
    }
    
    return error != nil;
}

#pragma mark - NSManagedObject Creation

- (NSArray*) fetchEntity:(NSString*) entityName
     primaryPropertyName:(NSString*) propertyName
    primaryPropertyValue:(int) primaryId
  inManagedObjectContext:(NSManagedObjectContext*) moc
{
    NSArray* toEntities = nil;
    @try {
        NSError* error;
        NSFetchRequest *toFetchRequest = [[NSFetchRequest alloc] init];
        [toFetchRequest setEntity:[NSEntityDescription entityForName:entityName inManagedObjectContext:moc]];
        NSString* predicateString = [NSString stringWithFormat:@"(%@ IN %@)", propertyName, @"%@"];
        [toFetchRequest setPredicate: [NSPredicate predicateWithFormat:predicateString,[NSArray arrayWithObject:[NSNumber numberWithInteger:primaryId]]]];
       toEntities = [moc executeFetchRequest:toFetchRequest error:&error];
        
        return toEntities;
    }
    @catch (NSException *exception) {
        NSLog(@"Exception while fetching with property %@ on %@: %@", propertyName, entityName, [exception debugDescription]);
    }
    
    return toEntities;
}

-(NSManagedObject*) createEntityFromResultSet:(FMResultSet*) results
                                withTableInfo:(SQCDTableInfo*) tableInfo
                       inManagedObjectContext:(NSManagedObjectContext*) moc
                       shouldCreateManyToMany:(BOOL) createM2M
{
    
    NSString* entityName = [tableInfo representedClassName];
    
    NSString *primaryProperty = [[tableInfo primaryColumn] nameForProperty];
    
    NSArray* existingEntities = [self fetchEntity:entityName
                                         primaryPropertyName:primaryProperty
                                        primaryPropertyValue:[results intForColumn:primaryProperty]
                                      inManagedObjectContext:moc];
    
    if (existingEntities.count > 0) {
        NSLog(@"Found Entity %@", entityName);
        return [existingEntities objectAtIndex:0];
    }
    
    NSLog(@"Creating Entity %@", entityName);
    
    id entity = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
    
    for (SQCDColumnInfo* columnInfo in [tableInfo.columns allValues]) {
        
        @autoreleasepool {
            SQCDForeignKeyInfo* foreignKeyInfo = [tableInfo.foreignKeys valueForKey:columnInfo.sqliteName];
            
            if (foreignKeyInfo != nil && ![foreignKeyInfo.toSqliteTableName isEqualToString:tableInfo.sqliteName]) {
                NSLog(@"Ingnoring foreignkey %@ from %@ to %@", foreignKeyInfo.fromSqliteColumnName, foreignKeyInfo.fromSqliteTableName, foreignKeyInfo.toSqliteTableName);
            }else{
                NSString* propertyName = [columnInfo nameForProperty];
                NSString* propertyType = [SQCDTypeMapper xctypeFromType:columnInfo.sqlliteType];
                
                id value = [self valueFromResultSet:results
                                                      forColumnName:columnInfo.sqliteName
                                                       propertyType:propertyType];
                @try {
                    [entity setValue:value forKey:propertyName];
                }
                @catch (NSException *exception) {
                    NSLog(@"Exception while setting %@ on %@: %@", propertyName, entityName, [exception debugDescription]);
                }
            }
        }
    }
    
    if (entity != nil) {
        @autoreleasepool {
            [self createRelationshipForEntity:entity
                                      inManagedObjectContext:moc
                                                   tableInfo:tableInfo
                                                   resultSet:results];
            
        }
        if (createM2M) {
            
            @autoreleasepool {
                [self createManyToManyFromEntity:entity
                                               withTableInfo:tableInfo
                                      inManagedObjectContext:moc];
            }
        }
        
    }
    
    return entity;
}

- (void) createManyToManyFromEntity:(NSManagedObject*) entity
                         withTableInfo:(SQCDTableInfo*) tableInfo
                inManagedObjectContext:(NSManagedObjectContext*) moc
{
    FMDatabase* database = [self openDatabase];

    NSString *primaryProperty = [[tableInfo primaryColumn] nameForProperty];

    NSDictionary *tablesDict = [self tableDictionary];
    
    NSDictionary* inverseDict = [tableInfo.helper inverseRelationships];
    
    NSArray* inverseForTable = [inverseDict objectForKey:tableInfo.sqliteName];
    
    for (SQCDForeignKeyInfo* inverseInfo in inverseForTable) {
        SQCDTableInfo* inverseSourceTableInfo = [tablesDict objectForKey:inverseInfo.toSqliteTableName];
        if ([inverseSourceTableInfo isManyToMany]) {
            // TODO migrate many to many
            SQCDForeignKeyInfo* m2mInfo = [tableInfo.helper manyToManyRelationFromTable:tableInfo.sqliteName
                                                                                  toTable:inverseSourceTableInfo.sqliteName];
            // Fetch results from db and create entities
            int fromColunmValue = [[entity valueForKey:primaryProperty] intValue];
            
            FMResultSet *resultSet = [database executeQuery:[NSString stringWithFormat:@"select * from %@ where %@=%d", inverseSourceTableInfo.sqliteName, inverseInfo.toSqliteColumnName, fromColunmValue]];
            
            NSUInteger count = [database intForQuery:[NSString stringWithFormat:@"select count(%@) from %@ where %@=%d",inverseInfo.toSqliteColumnName,inverseSourceTableInfo.sqliteName, inverseInfo.toSqliteColumnName, fromColunmValue]];
            
            NSMutableArray* relationEntities = [NSMutableArray array];
            
            SQCDTableInfo* toTableInfo = [tablesDict objectForKey:m2mInfo.toSqliteTableName];
            
            @autoreleasepool {
                while([resultSet next]) {
                    
                    int destValue = [resultSet intForColumn:[toTableInfo primaryColumn].sqliteName];
                    FMResultSet *destResults = [database executeQuery:[NSString stringWithFormat:@"select * from %@ where %@=%d ", toTableInfo.sqliteName, [toTableInfo primaryColumn].sqliteName, destValue]];
                    
                    while([destResults next]) {
                        NSManagedObject *relationEntity =  [self createEntityFromResultSet:destResults
                                                                                             withTableInfo:toTableInfo
                                                                                    inManagedObjectContext:moc
                                                                                    shouldCreateManyToMany:NO];
                        [relationEntities addObject:relationEntity];
                    }
                }
            }
            
            @try {
                NSLog(@"Creating Relation %@ form %@ to %@", m2mInfo.relationName, m2mInfo.fromSqliteTableName, m2mInfo.toSqliteTableName);
                // Set the reation property upon the fromEntity
                if (relationEntities.count == count) {
                    [entity setValue:[NSSet setWithArray:relationEntities] forKey:m2mInfo.relationName];
                }
            }
            @catch (NSException *exception) {
                NSLog(@"Exception while setting %@ on %@: %@", m2mInfo.relationName, entity.entity.name, [exception debugDescription]);
            }
        }
    }
    
//    [database close];

}

-(void) createRelationshipForEntity:(NSManagedObject*) fromEntity
             inManagedObjectContext:(NSManagedObjectContext*) moc
                          tableInfo:(SQCDTableInfo*) tableInfo
                          resultSet:(FMResultSet*) fromResultSet
{
    FMDatabase* database = [self openDatabase];
    
    // Fetch all the related entries from the destination table
    NSArray* foreignKeyInfo = [tableInfo.foreignKeys allValues];
    // Iterate over all foreign keys
    [foreignKeyInfo enumerateObjectsUsingBlock:^(SQCDForeignKeyInfo* relationInfo, NSUInteger idx, BOOL *stop) {
        
        if (![relationInfo.toSqliteTableName isEqualToString:tableInfo.sqliteName]) {
            
            // Get the destination table info
            NSDictionary *tablesDict = [self tableDictionary];
            SQCDTableInfo* toTableInfo = [tablesDict valueForKey:relationInfo.toSqliteTableName];
            
            // Fetch results from db and create entities
            int fromColumnValue = [fromResultSet intForColumn:relationInfo.fromSqliteColumnName];
            FMResultSet *results = [database executeQuery:[NSString stringWithFormat:@"select * from %@ where %@=%d", relationInfo.toSqliteTableName, relationInfo.toSqliteColumnName, fromColumnValue]];
            NSMutableArray* relationEntities = [NSMutableArray array];
            
            while([results next]) {
                NSLog(@"Creating Relation %@ form %@ to %@", relationInfo.relationName, fromEntity.entity.name, [relationInfo.toSqliteTableName capitalizedString]);

                NSManagedObject *relationEntity =  [self createEntityFromResultSet:results
                                                                                    withTableInfo:toTableInfo
                                                                           inManagedObjectContext:moc
                                                                            shouldCreateManyToMany:YES];
                [relationEntities addObject:relationEntity];
            }
            
            @try {
                // Set the reation property upon the fromEntity
                if (relationEntities.count) {
                    if (relationInfo.toMany) {
                        [fromEntity setValue:[NSSet setWithArray:relationEntities] forKey:relationInfo.relationName];
                    } else{
                        [fromEntity setValue:[relationEntities objectAtIndex:0] forKey:relationInfo.relationName];
                    }
                }
            }
            @catch (NSException *exception) {
                NSLog(@"Exception while setting %@ on %@: %@", relationInfo.relationName, fromEntity.entity.name, [exception debugDescription]);
            }
        }
    }];
    
//    [database close];
}

#pragma mark - DB helpers

- (id) valueFromResultSet:(FMResultSet*) results
            forColumnName:(NSString*) columnName
             propertyType:(NSString*) propertyType
{
    id value = nil;
    
    // TODO handle other values
    if ([propertyType isEqualToString:XCSTRING]) {
        value = [results stringForColumn:columnName];
    } else if ([propertyType isEqualToString:XCINT64] || [propertyType isEqualToString:XCINT32]){
        value = [NSNumber numberWithInt:[results intForColumn:columnName]];
    } else if ([propertyType isEqualToString:XCDECIMAL]){
        value = [NSDecimalNumber numberWithFloat:[[results stringForColumn:columnName] floatValue]];
    } else if ([propertyType isEqualToString:XCDATE]){
        value = [results dateForColumn:columnName];
    }else{
        value = [results objectForColumnName:columnName];
    }
    
    if ([value isKindOfClass:[NSNull class]]) {
        value = nil;
    }
    
    return value;
}

- (FMDatabase *)openDatabase
{
    if (self.dataBase) {
        return self.dataBase;
    }
    self.dataBase = [FMDatabase databaseWithPath:self.dbPath];
    if (![self.dataBase open]) {
        self.dataBase = nil;
        NSLog(@"Failed to open database!");
    }
    return self.dataBase;
}



@end
