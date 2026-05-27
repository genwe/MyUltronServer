//
//  MyUltronManager.m
//  MyUltronServer
//
//  Manager singleton — owns the server and all built-in business modules.
//

#import "MyUltronManager.h"
#import "../MyUltronServer.h"
#import "../Business/MyUltronBasic.h"
#import "../Business/MyUltronAppInfo.h"
#import "../Business/MyUltronSandbox.h"
#import "../Business/MyUltronUserDefaults.h"
#import "../Business/MyUltronSqlite.h"
#import "../Business/MyUltronLog.h"
#import "../Business/MyUltronScreenshot.h"
#import "../Business/MyUltronMessagePush.h"
#import "../Business/MyUltronNetworkMonitor.h"

@interface MyUltronManager ()

@property (nonatomic, strong, readwrite) MyUltronServer *server;

// Built-in modules
@property (nonatomic, strong) MyUltronBasic   *basicModule;
@property (nonatomic, strong) MyUltronAppInfo *appInfoModule;
@property (nonatomic, strong) MyUltronSandbox     *sandboxModule;
@property (nonatomic, strong) MyUltronUserDefaults *userDefaultsModule;
@property (nonatomic, strong) MyUltronSqlite      *sqliteModule;
@property (nonatomic, strong) MyUltronLog        *logModule;
@property (nonatomic, strong) MyUltronScreenshot  *screenshotModule;
@property (nonatomic, strong) MyUltronMessagePush   *messagePushModule;
@property (nonatomic, strong) MyUltronNetworkMonitor *networkMonitorModule;

@end

@implementation MyUltronManager

#pragma mark - Singleton

+ (void)load {
    // Cold-launch auto-start: the server begins listening as soon as
    // the class is loaded (which happens before main() with +load).
    // If you prefer manual start, remove this and call -start explicitly.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[MyUltronManager sharedInstance] start];
    });
}

+ (instancetype)sharedInstance {
    static MyUltronManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MyUltronManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _server = [[MyUltronServer alloc] initWithPort:62345];

        // Initialize built-in business modules
        _basicModule   = [[MyUltronBasic alloc]   initWithServer:_server];
        _appInfoModule = [[MyUltronAppInfo alloc] initWithServer:_server];
        _sandboxModule     = [[MyUltronSandbox alloc]     initWithServer:_server];
        _userDefaultsModule = [[MyUltronUserDefaults alloc] initWithServer:_server];
        _sqliteModule       = [[MyUltronSqlite alloc]      initWithServer:_server];
        _logModule          = [[MyUltronLog alloc]         initWithServer:_server];
        _screenshotModule   = [[MyUltronScreenshot alloc]  initWithServer:_server];
        _messagePushModule    = [[MyUltronMessagePush alloc]   initWithServer:_server];
        _networkMonitorModule = [[MyUltronNetworkMonitor alloc] initWithServer:_server];
    }
    return self;
}

- (void)dealloc {
    [self.server stopServer];
}

#pragma mark - Public API

- (void)start {
    [self.server startServer];
}

- (void)stop {
    [self.server stopServer];
}

- (void)applicationDidFinishLaunching {
    // Placeholder — extend for launch-time instrumentation.
}

- (void)applicationDidEnterBackground {
    [self.server appDidEnterBackground];
}

- (void)applicationWillEnterForeground {
    [self.server appWillEnterForeground];
}

@end
