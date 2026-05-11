//
//  MyUltronAppInfo.m
//  MyUltronServer
//
//  Responds to "appInfo" requests from the MyUltron client with
//  bundle ID, version, build number, and optional extra info.
//

#import "MyUltronAppInfo.h"
#import "../MyUltronServer.h"
#import "../Manager/MyUltronManager.h"

@interface MyUltronAppInfo () <MyUltronServerMessageDelegate>

@property (nonatomic, weak) MyUltronServer *server;

@end

@implementation MyUltronAppInfo

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;
        [server registerForMessageType:@"appInfo" delegate:self];
    }
    return self;
}

#pragma mark - MyUltronServerMessageDelegate

- (void)myUltronServerDidReceiveMessage:(NSDictionary *)dict {
    [self sendAppInfo];
}

#pragma mark - Build & Send

- (void)sendAppInfo {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *infoDict = [mainBundle infoDictionary];

    NSMutableDictionary *content = [NSMutableDictionary dictionary];

    // Merge optional extra info from the host app
    MyUltronExtraAppInfoBlock extraBlock = [MyUltronManager sharedInstance].extraAppInfo;
    if (extraBlock) {
        NSDictionary *extra = extraBlock();
        if (extra) {
            [content addEntriesFromDictionary:extra];
        }
    }

    // Standard keys
    content[@"bundleId"]      = [mainBundle bundleIdentifier] ?: @"unknown";
    content[@"appVersion"]    = infoDict[@"CFBundleShortVersionString"] ?: @"unknown";
    content[@"buildNumber"]   = infoDict[@"CFBundleVersion"] ?: @"unknown";
    content[@"appName"]       = infoDict[@"CFBundleDisplayName"]
                                ?: infoDict[@"CFBundleName"]
                                ?: @"unknown";
    content[@"osVersion"]     = [[UIDevice currentDevice] systemVersion];
    content[@"deviceModel"]   = [[UIDevice currentDevice] model];
    content[@"deviceName"]    = [[UIDevice currentDevice] name];

#if DEBUG
    content[@"configuration"] = @"Debug";
#else
    content[@"configuration"] = @"Release";
#endif

    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"appInfo",
        kMyUltronMsgKeyContent: content,
    }];
}

@end
