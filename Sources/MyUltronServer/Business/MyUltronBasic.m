//
//  MyUltronBasic.m
//  MyUltronServer
//
//  Sends a handshake message (version + bundle info) when the MyUltron client connects.
//

#import "MyUltronBasic.h"
#import "../MyUltronServer.h"

NSString * const kMyUltronServerVersion = @"1.0.0";

@interface MyUltronBasic ()

@property (nonatomic, weak) MyUltronServer *server;

@end

@implementation MyUltronBasic

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;

        // Listen for client connect to send handshake
        [[NSNotificationCenter defaultCenter]
         addObserver:self
            selector:@selector(onClientConnect)
                name:MyUltronServerDidConnectNotification
              object:server];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onClientConnect {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
    NSString *appName  = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
                         ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]
                         ?: @"unknown";

    NSDictionary *content = @{
        @"version":   kMyUltronServerVersion,
        @"bundleId":  bundleID,
        @"appName":   appName,
        @"platform":  @"iOS",
        @"osVersion": [[UIDevice currentDevice] systemVersion],
    };

    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"ultron",
        kMyUltronMsgKeyContent: content,
    }];
}

@end
