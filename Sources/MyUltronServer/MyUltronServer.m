//
//  MyUltronServer.m
//  MyUltronServer
//
//  Core server implementation: raw-packet → JSON → delegate routing.
//

#import "MyUltronServer.h"
#import "Socket/MyUltronSocket.h"
#import "Core/MyUltronPacket.h"

// MARK: - Constants

NSString * const kMyUltronMsgKeyVersion = @"version";
NSString * const kMyUltronMsgKeyType    = @"messageType";
NSString * const kMyUltronMsgKeyContent = @"content";

NSNotificationName const MyUltronServerDidConnectNotification    = @"MyUltronServerDidConnect";
NSNotificationName const MyUltronServerDidDisconnectNotification = @"MyUltronServerDidDisconnect";

// MARK: - Private Interface

@interface MyUltronServer () <MyUltronSocketDelegate>

@property (nonatomic, strong) MyUltronSocket *socket;
/// messageType → delegate (weak)
@property (nonatomic, strong) NSMapTable<NSString *, id<MyUltronServerMessageDelegate>> *delegateMap;

@end

@implementation MyUltronServer

#pragma mark - Lifecycle

- (instancetype)initWithPort:(uint32_t)port {
    self = [super init];
    if (self) {
        _socket = [[MyUltronSocket alloc] initWithPort:port delegate:self];
        _delegateMap = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

- (void)startServer {
    [self.socket start];
}

- (void)stopServer {
    [self.socket stop];
}

- (void)appDidEnterBackground {
    // No-op for now; socket stays alive for a short grace period.
}

- (void)appWillEnterForeground {
    [self.socket checkListeningStatus];
}

- (BOOL)isConnected {
    return self.socket.isConnected;
}

#pragma mark - Message Routing

- (void)registerForMessageType:(NSString *)messageType
                      delegate:(id<MyUltronServerMessageDelegate>)delegate {
    if (messageType.length == 0 || delegate == nil) return;
    [self.delegateMap setObject:delegate forKey:messageType];
}

- (void)sendMessage:(NSDictionary *)dict {
    [self sendMessageUnfiltered:dict];
}

- (void)sendMessageUnfiltered:(NSDictionary *)dict {
    if (dict == nil) return;
    if (dict[kMyUltronMsgKeyType] == nil || dict[kMyUltronMsgKeyContent] == nil) {
        NSLog(@"[MyUltron] sendMessage: missing messageType or content");
        return;
    }
    [self.socket sendJsonData:dict];
}

- (void)sendBinaryData:(NSData *)data {
    if (data == nil) return;
    [self.socket sendBinaryData:data];
}

#pragma mark - MyUltronSocketDelegate

- (void)socket:(MyUltronSocket *)socket
didReceivePacket:(struct myultron_packet *)packet {
    if (packet->header.packetType != MyUltronPacketTypeJsonMessage) {
        // Only JSON messages are routed; text/binary are ignored at this level.
        return;
    }

    size_t payloadLen = packet->header.length - MYULTRON_PACKET_HEADER_SIZE;
    if (payloadLen == 0) return;

    NSData *jsonData = [NSData dataWithBytes:packet->payload length:payloadLen];
    NSError *error = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:0
                                                           error:&error];
    if (error || ![dict isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[MyUltron] Invalid JSON packet: %@", error);
        return;
    }

    NSString *messageType = dict[kMyUltronMsgKeyType];
    if (messageType.length == 0) {
        NSLog(@"[MyUltron] Missing messageType in packet");
        return;
    }

    id<MyUltronServerMessageDelegate> delegate = [self.delegateMap objectForKey:messageType];
    if (delegate != nil) {
        NSLog(@"[MyUltron] Server routing '%@' → delegate", messageType);
        [delegate myUltronServerDidReceiveMessage:dict];
    } else {
        NSLog(@"[MyUltron] Server NO delegate for messageType: '%@'", messageType);
    }
}

- (void)socketClientDidConnect:(MyUltronSocket *)socket {
    [[NSNotificationCenter defaultCenter]
     postNotificationName:MyUltronServerDidConnectNotification object:self];
}

- (void)socketClientDidDisconnect:(MyUltronSocket *)socket {
    [[NSNotificationCenter defaultCenter]
     postNotificationName:MyUltronServerDidDisconnectNotification object:self];
}

@end
