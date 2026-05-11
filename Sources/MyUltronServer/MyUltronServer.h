//
//  MyUltronServer.h
//  MyUltronServer
//
//  Public API — the core message-routing server.
//  Integrators interact with `MyUltronManager` for lifecycle;
//  use this class only when you need custom message handlers.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: - Message dictionary keys

/// The message envelope: { version, messageType, content }
extern NSString * const kMyUltronMsgKeyVersion;
extern NSString * const kMyUltronMsgKeyType;
extern NSString * const kMyUltronMsgKeyContent;

// MARK: - Notification names

/// Posted when a MyUltron client connects.
extern NSNotificationName const MyUltronServerDidConnectNotification;
/// Posted when a MyUltron client disconnects.
extern NSNotificationName const MyUltronServerDidDisconnectNotification;

// MARK: - Delegate

@protocol MyUltronServerMessageDelegate <NSObject>

/// Called on the socket's serial queue when a message of the registered type arrives.
/// @param dict The full message dictionary (version / messageType / content).
- (void)myUltronServerDidReceiveMessage:(NSDictionary *)dict;

@end

// MARK: - Server

@interface MyUltronServer : NSObject

/// Designated initializer.
/// @param port TCP port to listen on.
- (instancetype)initWithPort:(uint32_t)port;

- (void)startServer;
- (void)stopServer;

/// Call from `applicationDidEnterBackground:`.
- (void)appDidEnterBackground;
/// Call from `applicationWillEnterForeground:` — re-checks listening status.
- (void)appWillEnterForeground;

- (BOOL)isConnected;

// ---- Message routing ----

/// Register a delegate to receive messages of a specific `messageType`.
- (void)registerForMessageType:(NSString *)messageType
                      delegate:(id<MyUltronServerMessageDelegate>)delegate;

/// Send a message dictionary. Must include keys `messageType` and `content`.
- (void)sendMessage:(NSDictionary *)dict;

/// Send a message dictionary without smart-auto filter.
- (void)sendMessageUnfiltered:(NSDictionary *)dict;

/// Send raw binary data (e.g. file contents).
- (void)sendBinaryData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
