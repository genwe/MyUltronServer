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
@protocol MyUltronServerMessageDelegate;

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

// ---- Module registration ----

/// Register a business module class. Modules call this in +load to self-register.
/// The class must implement -initWithServer: (taking a MyUltronServer *).
+ (void)registerModuleClass:(Class)cls;

// ---- Custom message handler ----

/// Register an external delegate for a custom message type.
/// External developers can call this to add custom business logic without
/// modifying MyUltronServer source code.
///
/// @param messageType The message type string (e.g. @"myFeature").
/// @param delegate    The handler conforming to MyUltronServerMessageDelegate.
- (void)registerForMessageType:(NSString *)messageType
                      delegate:(id<MyUltronServerMessageDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
