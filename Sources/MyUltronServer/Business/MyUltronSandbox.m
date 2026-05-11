//
//  MyUltronSandbox.m
//  MyUltronServer
//
//  Sandbox operations: list directory, create folder, delete items.
//  All paths are relative to NSHomeDirectory().
//

#import "MyUltronSandbox.h"
#import "../MyUltronServer.h"

@interface MyUltronSandbox () <MyUltronServerMessageDelegate>

@property (nonatomic, weak) MyUltronServer *server;

@end

@implementation MyUltronSandbox

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;
        [server registerForMessageType:@"sandboxList"      delegate:self];
        [server registerForMessageType:@"sandboxCreateDir" delegate:self];
        [server registerForMessageType:@"sandboxDelete"    delegate:self];
        [server registerForMessageType:@"sandboxDownload"  delegate:self];
        NSLog(@"[MyUltron] Sandbox module registered");
    }
    return self;
}

#pragma mark - MyUltronServerMessageDelegate

- (void)myUltronServerDidReceiveMessage:(NSDictionary *)dict {
    NSString *type = dict[kMyUltronMsgKeyType];
    NSDictionary *content = dict[kMyUltronMsgKeyContent];
    NSLog(@"[MyUltron] Sandbox ← messageType: %@", type);

    if ([type isEqualToString:@"sandboxList"]) {
        [self handleListRequest:content];
    } else if ([type isEqualToString:@"sandboxCreateDir"]) {
        [self handleCreateDirRequest:content];
    } else if ([type isEqualToString:@"sandboxDelete"]) {
        [self handleDeleteRequest:content];
    } else if ([type isEqualToString:@"sandboxDownload"]) {
        [self handleDownloadRequest:content];
    }
}

#pragma mark - List

- (void)handleListRequest:(NSDictionary *)content {
    NSString *requestPath = content[@"path"] ?: @"/";
    NSString *fullPath = [self resolvePath:requestPath];

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:fullPath isDirectory:&isDir] || !isDir) {
        [self respondList:requestPath entries:@[]];
        return;
    }

    NSError *error = nil;
    NSArray<NSString *> *names = [fm contentsOfDirectoryAtPath:fullPath error:&error];
    if (!names) {
        [self respondList:requestPath entries:@[]];
        return;
    }

    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:names.count];
    for (NSString *name in names) {
        NSString *itemFullPath = [fullPath stringByAppendingPathComponent:name];
        NSDictionary *attrs = [fm attributesOfItemAtPath:itemFullPath error:nil];
        if (!attrs) continue;

        BOOL itemIsDir = [attrs[NSFileType] isEqualToString:NSFileTypeDirectory];
        NSDate *modDate = attrs[NSFileModificationDate];
        int64_t size = itemIsDir ? 0 : [attrs[NSFileSize] longLongValue];

        NSString *itemRelativePath = [requestPath isEqualToString:@"/"]
            ? [@"/" stringByAppendingString:name]
            : [requestPath stringByAppendingPathComponent:name];

        NSString *dateStr = modDate
            ? [self formatDate:modDate]
            : @"";

        [entries addObject:@{
            @"name":    name,
            @"path":    itemRelativePath,
            @"isDir":   @(itemIsDir),
            @"size":    @(size),
            @"modDate": dateStr,
        }];
    }

    [self respondList:requestPath entries:entries];
}

- (void)respondList:(NSString *)path entries:(NSArray *)entries {
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"sandboxList",
        kMyUltronMsgKeyContent: @{
            @"path":    path,
            @"entries": entries,
        },
    }];
}

#pragma mark - Create Directory

- (void)handleCreateDirRequest:(NSDictionary *)content {
    NSString *requestPath = content[@"path"];
    if (requestPath.length == 0) {
        [self respondCreateDir:requestPath success:NO error:@"path is empty"];
        return;
    }

    NSString *fullPath = [self resolvePath:requestPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    BOOL ok = [fm createDirectoryAtPath:fullPath
            withIntermediateDirectories:NO
                             attributes:nil
                                  error:&error];
    [self respondCreateDir:requestPath
                   success:ok
                     error:ok ? @"" : error.localizedDescription];
}

- (void)respondCreateDir:(NSString *)path
                 success:(BOOL)success
                   error:(NSString *)error
{
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"sandboxCreateDir",
        kMyUltronMsgKeyContent: @{
            @"path":    path ?: @"",
            @"success": @(success),
            @"error":   error ?: @"",
        },
    }];
}

#pragma mark - Delete

- (void)handleDeleteRequest:(NSDictionary *)content {
    NSString *requestPath = content[@"path"];
    if (requestPath.length == 0) {
        [self respondDelete:requestPath success:NO error:@"path is empty"];
        return;
    }

    NSString *fullPath = [self resolvePath:requestPath];
    NSFileManager *fm = [NSFileManager defaultManager];

    // Prevent deleting the root sandbox
    if ([fullPath isEqualToString:NSHomeDirectory()]) {
        [self respondDelete:requestPath success:NO error:@"cannot delete root"];
        return;
    }

    NSError *error = nil;
    BOOL ok = [fm removeItemAtPath:fullPath error:&error];
    [self respondDelete:requestPath
                success:ok
                  error:ok ? @"" : error.localizedDescription];
}

- (void)respondDelete:(NSString *)path
              success:(BOOL)success
                error:(NSString *)error
{
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"sandboxDelete",
        kMyUltronMsgKeyContent: @{
            @"path":    path ?: @"",
            @"success": @(success),
            @"error":   error ?: @"",
        },
    }];
}

#pragma mark - Download

- (void)handleDownloadRequest:(NSDictionary *)content {
    NSString *requestPath = content[@"path"];
    if (requestPath.length == 0) {
        [self respondDownload:requestPath success:NO error:@"path is empty"];
        return;
    }

    NSString *fullPath = [self resolvePath:requestPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:fullPath isDirectory:&isDir] || isDir) {
        [self respondDownload:requestPath success:NO error:@"not a file"];
        return;
    }

    NSData *fileData = [NSData dataWithContentsOfFile:fullPath];
    if (!fileData) {
        [self respondDownload:requestPath success:NO error:@"cannot read file"];
        return;
    }

    // Send metadata JSON first, then binary file data
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"sandboxDownload",
        kMyUltronMsgKeyContent: @{
            @"path":    requestPath,
            @"success": @YES,
            @"size":    @(fileData.length),
            @"name":    [requestPath lastPathComponent],
        },
    }];

    // Then send the raw file bytes as a binary packet
    [self.server sendBinaryData:fileData];
}

- (void)respondDownload:(NSString *)path
                success:(BOOL)success
                  error:(NSString *)error
{
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"sandboxDownload",
        kMyUltronMsgKeyContent: @{
            @"path":    path ?: @"",
            @"success": @(success),
            @"error":   error ?: @"",
        },
    }];
}

#pragma mark - Helpers

/// Resolve a request path (relative to sandbox root) to an absolute path.
/// / → NSHomeDirectory()
/// /Documents → NSHomeDirectory()/Documents
- (NSString *)resolvePath:(NSString *)requestPath {
    if ([requestPath isEqualToString:@"/"] || requestPath.length == 0) {
        return NSHomeDirectory();
    }
    // Strip leading / to use as relative component
    NSString *rel = [requestPath hasPrefix:@"/"]
        ? [requestPath substringFromIndex:1]
        : requestPath;
    return [NSHomeDirectory() stringByAppendingPathComponent:rel];
}

- (NSString *)formatDate:(NSDate *)date {
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });
    return [fmt stringFromDate:date];
}

@end
