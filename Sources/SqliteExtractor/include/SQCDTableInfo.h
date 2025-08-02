//
//  SQLiteTableInfo.h
//  sqlite2coredata
//
//  Created by Tapasya on 22/08/13.
//  Copyright (c) 2013 Tapasya. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQCDColumnInfo.h"
@class SQCDDatabaseHelper;

@interface SQCDTableInfo : NSObject

-(instancetype) initWithHelper:(SQCDDatabaseHelper*) helper;
@property (nonatomic, readonly, strong) SQCDDatabaseHelper* helper;

@property (nonatomic, strong) NSDictionary* columns;

@property (nonatomic, strong) NSString* sqliteName;

@property (nonatomic, strong) NSString* sqlStatement;

@property (nonatomic, strong) NSDictionary* foreignKeys;

- (NSString*) representedClassName;

- (SQCDColumnInfo*) primaryColumn;

- (BOOL) isManyToMany;

-(NSXMLElement*) xmlRepresentation;

- (NSDictionary*) pListRepresentation;

@end
