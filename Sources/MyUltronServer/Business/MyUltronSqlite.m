//
//  MyUltronSqlite.m
//  MyUltronServer
//
//  SQLite 数据库管理：列出 .db 文件、查询表结构、数据浏览、增删改查。
//

#import "MyUltronSqlite.h"
#import "../MyUltronServer.h"
#import <sqlite3.h>

@interface MyUltronSqlite () <MyUltronServerMessageDelegate>
@property (nonatomic, weak) MyUltronServer *server;
@end

@implementation MyUltronSqlite

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;
        [server registerForMessageType:@"sqliteListDBs"   delegate:self];
        [server registerForMessageType:@"sqliteGetTables" delegate:self];
        [server registerForMessageType:@"sqliteQuery"     delegate:self];
        [server registerForMessageType:@"sqliteExecute"   delegate:self];
    }
    return self;
}

#pragma mark - Delegate

- (void)myUltronServerDidReceiveMessage:(NSDictionary *)dict {
    NSString *type = dict[kMyUltronMsgKeyType];
    NSDictionary *content = dict[kMyUltronMsgKeyContent];

    if ([type isEqualToString:@"sqliteListDBs"]) {
        [self handleListDBs];
    } else if ([type isEqualToString:@"sqliteGetTables"]) {
        [self handleGetTables:content];
    } else if ([type isEqualToString:@"sqliteQuery"]) {
        [self handleQuery:content];
    } else if ([type isEqualToString:@"sqliteExecute"]) {
        [self handleExecute:content];
    }
}

#pragma mark - Paths

- (NSString *)documentsPath {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

- (NSString *)dbPathForFile:(NSString *)filename {
    return [[self documentsPath] stringByAppendingPathComponent:filename];
}

- (sqlite3 *)openDB:(NSString *)filename {
    sqlite3 *db = NULL;
    NSString *path = [self dbPathForFile:filename];
    if (sqlite3_open(path.UTF8String, &db) != SQLITE_OK) {
        if (db) sqlite3_close(db);
        return NULL;
    }
    return db;
}

#pragma mark - List DB Files

- (void)handleListDBs {
    NSString *docPath = [self documentsPath];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docPath error:nil];
    NSMutableArray *dbFiles = [NSMutableArray array];
    for (NSString *f in files) {
        if ([f.pathExtension isEqualToString:@"db"] || [f.pathExtension isEqualToString:@"sqlite"]) {
            NSString *fullPath = [docPath stringByAppendingPathComponent:f];
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
            [dbFiles addObject:@{
                @"name": f,
                @"size": attrs[NSFileSize] ?: @0,
            }];
        }
    }
    [dbFiles sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];

    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"sqliteListDBs",
        kMyUltronMsgKeyContent: @{@"databases": dbFiles},
    }];
}

#pragma mark - Get Tables

- (void)handleGetTables:(NSDictionary *)content {
    NSString *dbName = content[@"database"];
    if (!dbName) {
        [self respondError:@"sqliteGetTables" message:@"Missing database name"]; return;
    }

    sqlite3 *db = [self openDB:dbName];
    if (!db) {
        [self respondError:@"sqliteGetTables" message:@"Cannot open database"]; return;
    }

    NSMutableArray *tables = [NSMutableArray array];

    // Get list of tables
    sqlite3_stmt *stmt = NULL;
    if (sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name", -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const char *tname = (const char *)sqlite3_column_text(stmt, 0);
            if (!tname) continue;
            NSString *tableName = @(tname);

            // Get columns for this table
            NSMutableArray *columns = [NSMutableArray array];
            char *createSQL = NULL;
            // Use PRAGMA table_info for column details
            sqlite3_stmt *colStmt = NULL;
            NSString *pragma = [NSString stringWithFormat:@"PRAGMA table_info('%@')", tableName];
            if (sqlite3_prepare_v2(db, pragma.UTF8String, -1, &colStmt, NULL) == SQLITE_OK) {
                while (sqlite3_step(colStmt) == SQLITE_ROW) {
                    const char *cname = (const char *)sqlite3_column_text(colStmt, 1);
                    const char *ctype = (const char *)sqlite3_column_text(colStmt, 2);
                    int pk = sqlite3_column_int(colStmt, 5);
                    [columns addObject:@{
                        @"name": cname ? @(cname) : @"?",
                        @"type": ctype ? @(ctype) : @"",
                        @"pk": @(pk),
                    }];
                }
                sqlite3_finalize(colStmt);
            }

            [tables addObject:@{
                @"name": tableName,
                @"columns": columns,
            }];
        }
        sqlite3_finalize(stmt);
    }

    sqlite3_close(db);

    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"sqliteGetTables",
        kMyUltronMsgKeyContent: @{@"database": dbName, @"tables": tables},
    }];
}

#pragma mark - Query Data

- (void)handleQuery:(NSDictionary *)content {
    NSString *dbName = content[@"database"];
    NSString *table  = content[@"table"];
    if (!dbName || !table) {
        [self respondError:@"sqliteQuery" message:@"Missing database/table"]; return;
    }

    sqlite3 *db = [self openDB:dbName];
    if (!db) {
        [self respondError:@"sqliteQuery" message:@"Cannot open database"]; return;
    }

    // Get column names first
    NSMutableArray *colNames = [NSMutableArray array];
    NSString *pragma = [NSString stringWithFormat:@"PRAGMA table_info('%@')", table];
    sqlite3_stmt *stmt = NULL;
    if (sqlite3_prepare_v2(db, pragma.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const char *cname = (const char *)sqlite3_column_text(stmt, 1);
            [colNames addObject:cname ? @(cname) : @"?"];
        }
        sqlite3_finalize(stmt);
    }

    // SELECT * LIMIT 1000
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM \"%@\" LIMIT 1000", table];
    NSMutableArray *rows = [NSMutableArray array];
    if (sqlite3_prepare_v2(db, sql.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
        int colCount = sqlite3_column_count(stmt);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NSMutableArray *row = [NSMutableArray arrayWithCapacity:colCount];
            for (int i = 0; i < colCount; i++) {
                int ctype = sqlite3_column_type(stmt, i);
                id val = [NSNull null];
                if (ctype == SQLITE_TEXT) {
                    const char *txt = (const char *)sqlite3_column_text(stmt, i);
                    val = txt ? @(txt) : @"";
                } else if (ctype == SQLITE_INTEGER) {
                    val = @(sqlite3_column_int64(stmt, i));
                } else if (ctype == SQLITE_FLOAT) {
                    val = @(sqlite3_column_double(stmt, i));
                } else if (ctype == SQLITE_BLOB) {
                    int bytes = sqlite3_column_bytes(stmt, i);
                    val = [NSString stringWithFormat:@"[BLOB %d bytes]", bytes];
                }
                [row addObject:val];
            }
            [rows addObject:row];
        }
        sqlite3_finalize(stmt);
    }

    sqlite3_close(db);

    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"sqliteQuery",
        kMyUltronMsgKeyContent: @{
            @"database": dbName,
            @"table": table,
            @"columns": colNames,
            @"rows": rows,
        },
    }];
}

#pragma mark - Execute (INSERT/UPDATE/DELETE)

- (void)handleExecute:(NSDictionary *)content {
    NSString *dbName = content[@"database"];
    NSString *sql    = content[@"sql"];
    if (!dbName || !sql) {
        [self respondError:@"sqliteExecute" message:@"Missing database/sql"]; return;
    }

    sqlite3 *db = [self openDB:dbName];
    if (!db) {
        [self.server sendMessage:@{
            kMyUltronMsgKeyVersion: @"1.0",
            kMyUltronMsgKeyType:    @"sqliteExecute",
            kMyUltronMsgKeyContent: @{@"success": @NO, @"error": @"Cannot open database"},
        }];
        return;
    }

    char *errMsg = NULL;
    int rc = sqlite3_exec(db, sql.UTF8String, NULL, NULL, &errMsg);
    sqlite3_close(db);

    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"sqliteExecute",
        kMyUltronMsgKeyContent: @{
            @"success": @(rc == SQLITE_OK),
            @"error": errMsg ? @(errMsg) : [NSNull null],
            @"rowsChanged": @(sqlite3_changes(db)),
        },
    }];
    if (errMsg) sqlite3_free(errMsg);
}

#pragma mark - Helpers

- (void)respondError:(NSString *)type message:(NSString *)msg {
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    type,
        kMyUltronMsgKeyContent: @{@"error": msg},
    }];
}

@end
