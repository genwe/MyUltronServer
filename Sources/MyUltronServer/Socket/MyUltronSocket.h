//
//  MyUltronSocket.h
//  MyUltronServer
//
//  TCP socket server layer. Manages listening, client connections,
//  packet framing, and raw I/O on a background serial queue.
//

#import <Foundation/Foundation.h>

// Forward-declare the packet struct so the delegate protocol can reference it
// without pulling in the full Core header.
struct myultron_packet;

NS_ASSUME_NONNULL_BEGIN

@protocol MyUltronSocketDelegate;

// MARK: - Packet read tag constants

/// First read: 4 bytes for packet length (wire: int32_t)
extern const long kMyUltronPacketTagLength;
/// Second read: the remaining (length - 4) bytes
extern const long kMyUltronPacketTagContent;

/// Length prefix size in bytes
extern const NSInteger kMyUltronPacketLengthByteCount;

@interface MyUltronSocket : NSObject

- (instancetype)initWithPort:(uint32_t)port
                    delegate:(id<MyUltronSocketDelegate>)delegate;

- (void)start;
- (void)stop;

/// Re-check listening status on foreground. Restarts if needed.
- (void)checkListeningStatus;

/// Whether a client is currently connected.
- (BOOL)isConnected;

/// Send a plain-text message.
- (void)sendText:(NSString *)text;
/// Send a JSON dictionary as a packet.
- (void)sendJsonData:(NSDictionary *)dict;
/// Send arbitrary binary data.
- (void)sendBinaryData:(NSData *)data;

@end

// MARK: - Delegate

@protocol MyUltronSocketDelegate <NSObject>

@required
/// Called when a complete packet is received.
/// @warning The packet pointer is owned by the socket; do NOT retain or free it.
- (void)socket:(MyUltronSocket *)socket
  didReceivePacket:(struct myultron_packet *)packet;

/// Client connected.
- (void)socketClientDidConnect:(MyUltronSocket *)socket;
/// Client disconnected (or error).
- (void)socketClientDidDisconnect:(MyUltronSocket *)socket;

@end

NS_ASSUME_NONNULL_END
