//
//  MyUltronSqlite.h
//  MyUltronServer
//
//  SQLite inspector — list database files, browse tables, CRUD operations.
//

#import <Foundation/Foundation.h>
#import "MyUltronModule.h"

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

@interface MyUltronSqlite : NSObject <MyUltronModule>

- (instancetype)initWithServer:(MyUltronServer *)server;

@end

NS_ASSUME_NONNULL_END
