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

@interface MyUltronManager ()

@property (nonatomic, strong, readwrite) MyUltronServer *server;

// Built-in modules
@property (nonatomic, strong) MyUltronBasic   *basicModule;
@property (nonatomic, strong) MyUltronAppInfo *appInfoModule;

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
        // Default port — can be overridden per app.
        // In production, you may want to use a scheme derived from the bundle ID.
        uint32_t listenPort = 62345;

        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleID hasSuffix:@".debug"] || [bundleID hasSuffix:@".adhoc"]) {
            // Debug / ad-hoc builds use a different port to avoid collisions
            listenPort = 72345;
        }

        _server = [[MyUltronServer alloc] initWithPort:listenPort];

        // Initialize built-in business modules
        _basicModule   = [[MyUltronBasic alloc]   initWithServer:_server];
        _appInfoModule = [[MyUltronAppInfo alloc] initWithServer:_server];
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
