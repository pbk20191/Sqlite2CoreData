//
//  SQCDDatabaseHelper.m
//  sqlite2coredata
//
//  Created by Tapasya on 27/08/13.
//  Copyright (c) 2013 Tapasya. All rights reserved.
//

#import "SQCDDatabaseHelper.h"
@import RegexKitLite;

@implementation SQCDDatabaseHelper

- (instancetype)init
{
    self = [super init];
    if (self) {
        self->_inverseRelationships = NSMutableDictionary.dictionary;
        self->_manyToManyRelationships = NSMutableDictionary.dictionary;
    }
    return self;
}

-(SQCDDatabaseHelper*) linkedChild {
    SQCDDatabaseHelper* child = SQCDDatabaseHelper.new;
    self->_inverseRelationships = self.inverseRelationships;
    self->_manyToManyRelationships = self.manyToManyRelationships;
    return self;
}

- (NSDictionary*) fetchTableInfos:(NSString*) dbPath
{
    
    sqlite3*            _db;
    
    int err = sqlite3_open([dbPath fileSystemRepresentation], &_db );
    if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
    }else{
        
        sqlite3_stmt* statement;
        NSString *query = @"SELECT name, sql FROM sqlite_master WHERE type=\'table\'";
        int retVal = sqlite3_prepare_v2(_db,
                                        [query UTF8String],
                                        -1,
                                        &statement,
                                        NULL);
        
        NSMutableDictionary *tableInfos = [NSMutableDictionary dictionary];
        if ( retVal == SQLITE_OK )
        {
            while(sqlite3_step(statement) == SQLITE_ROW )
            {
                NSString *tableName = [NSString stringWithCString:(const char *)sqlite3_column_text(statement, 0)
                                                         encoding:NSUTF8StringEncoding];
                NSString *tableSql = [NSString stringWithCString:(const char *)sqlite3_column_text(statement, 1)
                                                        encoding:NSUTF8StringEncoding];
                SQCDTableInfo* tableInfo = [[SQCDTableInfo alloc] initWithHelper:[self linkedChild]];
                tableInfo.sqliteName = tableName;
                tableInfo.sqlStatement = tableSql;
                
                tableInfo.columns = [self allColumnsInTableNamed:tableInfo.sqliteName dbPath:dbPath];
                
                tableInfo.foreignKeys = [self allForeignKeysInTable:tableInfo inDatabase:_db];
                
//                // Determine relationship cardinality
//                for (SQCDForeignKeyInfo* foreignKeyInfo in [tableInfo.foreignKeys allValues]) {
//                    [SQCDDatabaseHelper addInverseRelation:foreignKeyInfo];
//                }
                
                [tableInfos setValue:tableInfo forKey:tableName];
            }
        }
        
        sqlite3_clear_bindings(statement);
        sqlite3_finalize(statement);
        sqlite3_close(_db);
        
        [self generateManyToManyInfo:tableInfos];
        
        return tableInfos;
    }
    
    return nil;
    
}

- (void) generateManyToManyInfo:(NSDictionary*) tablesDict
{
    [[self manyToManyRelationships] removeAllObjects];
    
    NSArray* inverseRelations = [[self inverseRelationships] allValues];
    
    for (NSArray* inverseRelationForTable in inverseRelations ) {
        for (SQCDForeignKeyInfo* inverseInfo in inverseRelationForTable) {
            
            SQCDTableInfo* sourceTableInfo = [tablesDict objectForKey:inverseInfo.toSqliteTableName];
            
            if ([sourceTableInfo isManyToMany]) {
                
                NSArray* foreignKeys = [sourceTableInfo.foreignKeys allValues];
                
                SQCDForeignKeyInfo* otherForeignKey = [[[foreignKeys objectAtIndex:0] toSqliteTableName] isEqualToString:inverseInfo.fromSqliteTableName] ? [foreignKeys objectAtIndex:1] : [foreignKeys objectAtIndex:0];
                
                // Add relationship to the actual entity instead of the non existent many to many entity
                SQCDForeignKeyInfo* manyToManyRelation = [inverseInfo copy];
                manyToManyRelation.isInverse = NO;
                manyToManyRelation.toMany = YES;
                manyToManyRelation.fromSqliteTableName = inverseInfo.fromSqliteTableName;
                manyToManyRelation.toSqliteTableName = otherForeignKey.toSqliteTableName;
                manyToManyRelation.relationName = [[[manyToManyRelation.toSqliteTableName underscore ] pluralize] camelizeWithLowerFirstLetter];
                manyToManyRelation.invRelationName = [[[manyToManyRelation.fromSqliteTableName underscore ] pluralize] camelizeWithLowerFirstLetter];
                manyToManyRelation.isOptional = YES;
                [self addManyToManyRelation:manyToManyRelation forKey:sourceTableInfo.sqliteName];
            }
        }
    }

}

- (NSDictionary*) allForeignKeysInTable:(SQCDTableInfo*)tableInfo inDatabase:(sqlite3*) db
{
    NSArray* uniqColumns = [self allUniqueColumnsInTableNamed:tableInfo.sqliteName inDatabase:db];
    sqlite3_stmt* statement;
    NSString *query = [[NSString alloc] initWithFormat:@"pragma foreign_key_list(%@)", tableInfo.sqliteName];
    int retVal = sqlite3_prepare_v2(db,
                                    [query UTF8String],
                                    -1,
                                    &statement,
                                    NULL);
    
    NSMutableDictionary *foreignKeyInfos = [NSMutableDictionary dictionary];
    if ( retVal == SQLITE_OK )
    {
        while(sqlite3_step(statement) == SQLITE_ROW )
        {
            NSString *toTableName = [NSString stringWithCString:(const char *)sqlite3_column_text(statement, 2)
                                                     encoding:NSUTF8StringEncoding];
            NSString *fromColName = [NSString stringWithCString:(const char *)sqlite3_column_text(statement, 3)
                                                    encoding:NSUTF8StringEncoding];

            NSString *toColName = [NSString stringWithCString:(const char *)sqlite3_column_text(statement, 4)
                                                       encoding:NSUTF8StringEncoding];
            NSString *onDeleteAction = [NSString stringWithCString:(const char *)sqlite3_column_text(statement, 6)
                                                          encoding:NSUTF8StringEncoding];

            SQCDForeignKeyInfo* fkInfo = [SQCDForeignKeyInfo new];
            fkInfo.fromSqliteTableName = tableInfo.sqliteName;
            fkInfo.toSqliteTableName = toTableName;
            fkInfo.fromSqliteColumnName = fromColName;
            fkInfo.toSqliteColumnName = toColName;
            fkInfo.toMany = NO;
            fkInfo.relationName = [[toTableName underscore] camelizeWithLowerFirstLetter];
            fkInfo.sqliteOnDeleteAction = nil;
            fkInfo.xcOnDeleteAction = XCNULLIFY;
            // if foreign-key column allows null, then the relationship is marked optional
            BOOL fKeyColAllowsNull = [[tableInfo.columns objectForKey:fromColName] isNonNull]==NO;
            fkInfo.isOptional = fKeyColAllowsNull;
            
            // Build inverse relationship object
            SQCDForeignKeyInfo* invFKInfo = [SQCDForeignKeyInfo new];
            invFKInfo.fromSqliteTableName = fkInfo.toSqliteTableName;
            invFKInfo.toSqliteTableName = fkInfo.fromSqliteTableName;
            invFKInfo.fromSqliteColumnName = fkInfo.toSqliteColumnName;
            invFKInfo.toSqliteColumnName = fkInfo.fromSqliteColumnName;
            invFKInfo.toMany = [uniqColumns containsObject:fkInfo.fromSqliteColumnName]==NO;
            if (invFKInfo.toMany) {
                invFKInfo.relationName = [[[invFKInfo.toSqliteTableName underscore] pluralize] camelizeWithLowerFirstLetter];
            }else{
                invFKInfo.relationName = [[invFKInfo.toSqliteTableName underscore] camelizeWithLowerFirstLetter];
            }
            fkInfo.invRelationName = invFKInfo.relationName;
            invFKInfo.invRelationName = fkInfo.relationName;
            invFKInfo.isInverse = YES;
            // set the ON DELETE actions for inverse relationship
            invFKInfo.sqliteOnDeleteAction = onDeleteAction;
            NSString* capitalizedAction = [onDeleteAction capitalizedString];
            if ([@[@"SET NULL",@"SET DEFAULT"] containsObject:capitalizedAction]) {
                invFKInfo.xcOnDeleteAction = XCNULLIFY;
            }else if ([capitalizedAction isEqualToString:@"RESTRICT"]){
                invFKInfo.xcOnDeleteAction = XCDENY;
            }else if ([capitalizedAction isEqualToString:@"CASCADE"]){
                invFKInfo.xcOnDeleteAction = XCCASCADE;
            }else if ([capitalizedAction isEqualToString:@"NO ACTION"]){
                invFKInfo.xcOnDeleteAction = (fkInfo.isOptional ? XCNULLIFY : XCDENY);
            }else{
                NSLog(@"Using '%@' as delete rule for unknown sqlite ON DELETE action '%@'",XCNOACTION, capitalizedAction);
                invFKInfo.xcOnDeleteAction = XCNOACTION;
            }

            // inverse relationships are always optional
            invFKInfo.isOptional = YES;
            
            [foreignKeyInfos setValue:fkInfo forKey:fkInfo.fromSqliteColumnName];
            [self addInverseRelation:invFKInfo];
        }
    }
    
    sqlite3_clear_bindings(statement);
    sqlite3_finalize(statement);
    
    return foreignKeyInfos;

}

- (NSDictionary*) allColumnsInTableNamed:(NSString*)tableName dbPath:(NSString*) dbPath
{
    // Will return nil if fails, empty dict if no columns
    
    sqlite3*            _db;
    
    int err = sqlite3_open([dbPath fileSystemRepresentation], &_db );
    if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
    }else{
        char* errMsg = NULL ;
        int result ;
        
        NSString* statement ;
        statement = [[NSString alloc] initWithFormat:@"pragma table_info(%@)", tableName] ;
        char** results ;
        int nRows ;
        int nColumns ;
        result = sqlite3_get_table(
                                   _db,        /* An open database */
                                   [statement UTF8String], /* SQL to be executed */ &results, /* Result is in char *[] that this points to */ &nRows, /* Number of result rows written here */ &nColumns, /* Number of result columns written here */
                                   &errMsg    /* Error msg written here */
                                   ) ;
        
        
        NSDictionary* columnInfos = nil ;
        if (!(result == SQLITE_OK)) {
            // Invoke the error handler for this class
            //        [self showError:errMsg from:16 code:result] ;
            sqlite3_free(errMsg) ;
        }
        else {
            int nameColumnIndex = 0;
            int typeColumnIndex = 0;
            int nonnullColumnIndex = 0;
            int pkColumnIndex = 0;
            for (int j=0; j<nColumns; j++) {
                if (strcmp(results[j], "name") == 0) {
                    nameColumnIndex = j;
                } else if(strcmp(results[j], "type") == 0){
                    typeColumnIndex = j;
                } else if (strcmp(results[j], "pk") == 0){
                        pkColumnIndex = j;
                } else if (strcmp(results[j], "notnull") == 0){
                    nonnullColumnIndex = j;
                }
            }
            
            if (nameColumnIndex<nColumns && typeColumnIndex < nColumns) {
                int i ;
                columnInfos = [[NSMutableDictionary alloc] init] ;
                for (i=0; i<nRows; i++) {
                    SQCDColumnInfo* column = [[SQCDColumnInfo alloc] init];
                    column.sqliteName = [NSString stringWithCString:results[(i+1)*nColumns + nameColumnIndex] encoding:NSUTF8StringEncoding];
                    column.sqlliteType = [NSString stringWithCString:results[(i+1)*nColumns + typeColumnIndex] encoding:NSUTF8StringEncoding];
                    column.isNonNull = [[NSString stringWithCString:results[(i+1)*nColumns + nonnullColumnIndex] encoding:NSUTF8StringEncoding] boolValue];
                    column.isPrimaryKey = [[NSString stringWithCString:results[(i+1)*nColumns + pkColumnIndex] encoding:NSUTF8StringEncoding] boolValue];
                    column.sqliteTableName = tableName;
                    // TO DO default value reading
                    [columnInfos setValue:column forKey:column.sqliteName] ;
                }
            }
        }
        sqlite3_free_table(results) ;
        
        sqlite3_close(_db);
        
        NSDictionary* output = nil ;
        if (columnInfos != nil) {
            output = [columnInfos copy] ;
        }
        
        return output ;
    }
    
    return nil;
}

- (void) addInverseRelation:(SQCDForeignKeyInfo*) invForeignKeyInfo
{
    NSMutableArray* inverseRelationForTable = [[self inverseRelationships] valueForKey:invForeignKeyInfo.fromSqliteTableName];
    if (nil == inverseRelationForTable) {
        inverseRelationForTable = [NSMutableArray array];
    }
        
    [inverseRelationForTable addObject:invForeignKeyInfo];
    
    [[self inverseRelationships] setValue:inverseRelationForTable forKey:invForeignKeyInfo.fromSqliteTableName];
}

- (void) addManyToManyRelation:(SQCDForeignKeyInfo*) manyToManyInfo forKey:(NSString*) key
{
    NSMutableDictionary* m2mForTable = [[self manyToManyRelationships] valueForKey:manyToManyInfo.fromSqliteTableName];
    if (nil == m2mForTable) {
        m2mForTable = [NSMutableDictionary dictionary];
    }
    
    [m2mForTable setObject:manyToManyInfo forKey:key];
    
    [[self manyToManyRelationships] setValue:m2mForTable forKey:manyToManyInfo.fromSqliteTableName];
}

-(SQCDForeignKeyInfo*) manyToManyRelationFromTable:(NSString *)fromTableName toTable:(NSString *)toTableName
{
    NSDictionary* m2mInfo = [[self manyToManyRelationships] valueForKey:fromTableName];
    
    return [m2mInfo objectForKey:toTableName];

}



-(NSArray*)allUniqueColumnsInTableNamed:(NSString*)tableName inDatabase:(sqlite3*) db
{
    sqlite3_stmt* idxListStmt;
    NSString *query = [[NSString alloc] initWithFormat:@"pragma index_list(%@)", tableName];
    int retVal = sqlite3_prepare_v2(db,
                                    [query UTF8String],
                                    -1,
                                    &idxListStmt,
                                    NULL);
    
    NSMutableArray *uniqIndexes = [NSMutableArray array];
    if ( retVal == SQLITE_OK )
    {
        while(sqlite3_step(idxListStmt) == SQLITE_ROW )
        {
            NSString *unique = [NSString stringWithCString:(const char *)sqlite3_column_text(idxListStmt, 2)
                                                       encoding:NSUTF8StringEncoding];
            if ([unique intValue] > 0) {
                NSString* indexName = [NSString stringWithCString:(const char *)sqlite3_column_text(idxListStmt, 1)
                                                         encoding:NSUTF8StringEncoding];
                [uniqIndexes addObject:indexName];
            }
        }
    }
    sqlite3_clear_bindings(idxListStmt);
    sqlite3_finalize(idxListStmt);
    
    // get the corresponding column names
    NSMutableArray* uniqColumns = [NSMutableArray array];
    for (NSString* indexName in uniqIndexes) {
        sqlite3_stmt* colNameStmt;
        NSString *query = [[NSString alloc] initWithFormat:@"pragma index_info(%@)", indexName];
        int retVal = sqlite3_prepare_v2(db,
                                        [query UTF8String],
                                        -1,
                                        &colNameStmt,
                                        NULL);
        if ( retVal == SQLITE_OK )
        {
            while(sqlite3_step(colNameStmt) == SQLITE_ROW )
            {
                NSString *colName = [NSString stringWithCString:(const char *)sqlite3_column_text(colNameStmt, 2)
                                                      encoding:NSUTF8StringEncoding];
                [uniqColumns addObject:colName];
            }
        }
        sqlite3_clear_bindings(colNameStmt);
        sqlite3_finalize(colNameStmt);
    }
    
    return uniqColumns;
}

@end
