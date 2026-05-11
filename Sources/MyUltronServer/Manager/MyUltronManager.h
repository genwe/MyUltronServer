//
//  MyUltronManager.h
//  MyUltronServer
//
//  Main entry point for integrators.
//  Use +sharedInstance to obtain the manager, then call -start.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A block that returns additional app-info to send to the MyUltron client.
typedef NSDictionary * _Nonnull (^MyUltronExtraAppInfoBlock)(void);

@class MyUltronServer;

@interface MyUltronManager : NSObject

/// The underlying server instance.
@property (nonatomic, strong, readonly) MyUltronServer *server;

/// Optional block that provides host-app-specific information
/// (bundle ID, device ID, custom keys, etc.) to send to the MyUltron client.
@property (nonatomic, copy, nullable) MyUltronExtraAppInfoBlock extraAppInfo;

/// Singleton.
+ (instancetype)sharedInstance;

/// Start the TCP server. Safe to call multiple times.
- (void)start;

/// Stop the TCP server.
- (void)stop;

// ---- App lifecycle hooks (call from your AppDelegate) ----

- (void)applicationDidFinishLaunching;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;

@end

NS_ASSUME_NONNULL_END
