//
//  MyUltronSocket.m
//  MyUltronServer
//
//  TCP socket server implementation using GCDAsyncSocket.
//

#import "MyUltronSocket.h"
#import "../Core/MyUltronPacket.h"
#import "../Core/MyUltronPacketBuilder.h"

#import <CocoaAsyncSocket/GCDAsyncSocket.h>

// ---- Extern constant definitions (declared in MyUltronSocket.h) ----
const long      kMyUltronPacketTagLength       = 1;
const long      kMyUltronPacketTagContent      = 2;
const NSInteger kMyUltronPacketLengthByteCount = 4;

@interface MyUltronSocket () <GCDAsyncSocketDelegate>

@property (nonatomic, weak)   id<MyUltronSocketDelegate> delegate;
@property (nonatomic, assign) uint32_t              port;
@property (nonatomic, strong) dispatch_queue_t      socketQueue;
@property (nonatomic, strong) GCDAsyncSocket       *listenSocket;
@property (nonatomic, strong) GCDAsyncSocket       *clientSocket;

// Packet builder (C++ object wrapped as NSValue / raw pointer)
@property (nonatomic, assign) MyUltronPacketBuilder *builder;
@property (nonatomic, strong) NSMutableData        *readBuffer;

// Cached outbound data when no client is connected (e.g. during launch)
@property (nonatomic, assign) BOOL                  launchPhaseFinished;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *cachedSendQueue;

@end

@implementation MyUltronSocket

#pragma mark - Lifecycle

- (instancetype)initWithPort:(uint32_t)port
                    delegate:(id<MyUltronSocketDelegate>)delegate {
    self = [super init];
    if (self) {
        _port     = port;
        _delegate = delegate;

        _socketQueue = dispatch_queue_create("com.myultron.socket.queue",
                                             DISPATCH_QUEUE_SERIAL);
        _builder      = new MyUltronPacketBuilder();
        _readBuffer   = [NSMutableData data];
        _cachedSendQueue = [NSMutableArray array];

        // After ~8 seconds, treat launch phase as done.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            self.launchPhaseFinished = YES;
            [self flushCachedSendQueue];
        });
    }
    return self;
}

- (void)dealloc {
    if (_builder != nullptr) {
        delete _builder;
        _builder = nullptr;
    }
}

#pragma mark - Public API

- (void)start {
    dispatch_async(self.socketQueue, ^{
        if (self.listenSocket != nil) {
            return;
        }
        [self _tryListenFromPort:self.port toPort:self.port + 100];
    });
}

- (void)_tryListenFromPort:(uint32_t)fromPort toPort:(uint32_t)toPort {
    if (fromPort > toPort) {
        NSLog(@"[MyUltron] All ports in range %u-%u are occupied", self.port, toPort);
        return;
    }

    GCDAsyncSocket *sock = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                      delegateQueue:self.socketQueue];
    NSError *error = nil;
    if (![sock acceptOnPort:fromPort error:&error]) {
        if (error.code == 48 || error.code == 49) {
            // EADDRINUSE (48) or EADDRNOTAVAIL (49) — try next port
            NSLog(@"[MyUltron] Port %u unavailable (%@), trying next...", fromPort, error);
            [self _tryListenFromPort:fromPort + 1 toPort:toPort];
        } else {
            NSLog(@"[MyUltron] Failed to listen on port %u: %@", fromPort, error);
        }
        return;
    }

    self.listenSocket = sock;
    self.port = fromPort;
    NSLog(@"[MyUltron] Listening on port %u", (unsigned int)[sock localPort]);
}

- (void)stop {
    dispatch_async(self.socketQueue, ^{
        [self.listenSocket disconnect];
        self.listenSocket = nil;

        [self.clientSocket disconnect];
        self.clientSocket = nil;

        NSLog(@"[MyUltron] Server stopped");
    });
}

- (void)checkListeningStatus {
    dispatch_async(self.socketQueue, ^{
        // The listen socket creates the underlying file descriptor that
        // keeps the port bound. If it's still alive, the server is listening.
        if (self.listenSocket != nil || self.clientSocket != nil) {
            return;
        }
        [self stop];
        [self start];
    });
}

- (BOOL)isConnected {
    return self.clientSocket != nil;
}

#pragma mark - Send

- (void)sendText:(NSString *)text {
    dispatch_async(self.socketQueue, ^{
        if (self.clientSocket == nil) {
            [self cacheIfNeeded:nil];
            return;
        }
        self.builder->buildTextPacket(text);
        myultron_packet_t *pkt = self.builder->getPacket();
        NSData *data = [NSData dataWithBytes:pkt length:pkt->header.length];
        [self.clientSocket writeData:data withTimeout:-1 tag:0];
    });
}

- (void)sendJsonData:(NSDictionary *)dict {
    dispatch_async(self.socketQueue, ^{
        if (self.clientSocket == nil) {
            [self cacheIfNeeded:dict];
            return;
        }
        self.builder->buildJsonPacket(dict);
        myultron_packet_t *pkt = self.builder->getPacket();
        if (pkt == nullptr) return; // invalid JSON
        NSData *data = [NSData dataWithBytes:pkt length:pkt->header.length];
        [self.clientSocket writeData:data withTimeout:-1 tag:0];
    });
}

- (void)sendBinaryData:(NSData *)data {
    dispatch_async(self.socketQueue, ^{
        if (self.clientSocket == nil) return;
        self.builder->buildBinaryPacket(data);
        myultron_packet_t *pkt = self.builder->getPacket();
        NSData *outData = [NSData dataWithBytes:pkt length:pkt->header.length];
        [self.clientSocket writeData:outData withTimeout:-1 tag:0];
    });
}

#pragma mark - Internal: Heartbeat

- (void)sendPing {
    dispatch_async(self.socketQueue, ^{
        if (self.clientSocket == nil) return;
        self.builder->buildPingPacket();
        myultron_packet_t *pkt = self.builder->getPacket();
        NSData *data = [NSData dataWithBytes:pkt length:pkt->header.length];
        [self.clientSocket writeData:data withTimeout:-1 tag:0];
    });
}

- (void)sendPong {
    dispatch_async(self.socketQueue, ^{
        if (self.clientSocket == nil) return;
        self.builder->buildPongPacket();
        myultron_packet_t *pkt = self.builder->getPacket();
        NSData *data = [NSData dataWithBytes:pkt length:pkt->header.length];
        [self.clientSocket writeData:data withTimeout:-1 tag:0];
    });
}

#pragma mark - Caching (launch-phase buffer)

- (void)cacheIfNeeded:(NSDictionary * _Nullable)dict {
    if (!self.launchPhaseFinished && dict != nil) {
        [self.cachedSendQueue addObject:dict];
    }
}

- (void)flushCachedSendQueue {
    dispatch_async(self.socketQueue, ^{
        if (self.clientSocket == nil) {
            [self.cachedSendQueue removeAllObjects];
            return;
        }
        NSArray *snapshot = [self.cachedSendQueue copy];
        for (NSDictionary *dict in snapshot) {
            [self sendJsonData:dict];
        }
        [self.cachedSendQueue removeAllObjects];
    });
}

#pragma mark - Buffer helpers

- (void)resetReadBuffer {
    [self.readBuffer resetBytesInRange:NSMakeRange(0, self.readBuffer.length)];
    [self.readBuffer setLength:0];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock
didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    // Disconnect previous client if any (single-client policy)
    if (self.clientSocket != nil) {
        [self.clientSocket disconnect];
    }
    self.clientSocket = newSocket;

    NSLog(@"[MyUltron] Client connected: %@:%hu",
          [newSocket connectedHost], [newSocket connectedPort]);

    // Kick off packet-length read
    [self.clientSocket readDataToLength:kMyUltronPacketLengthByteCount
                            withTimeout:-1
                                    tag:kMyUltronPacketTagLength];

    if ([self.delegate respondsToSelector:@selector(socketClientDidConnect:)]) {
        [self.delegate socketClientDidConnect:self];
    }

    [self flushCachedSendQueue];
}

- (void)socket:(GCDAsyncSocket *)sock
   didReadData:(NSData *)data
       withTag:(long)tag {

    NSLog(@"[MyUltron] Socket read %lu bytes, tag=%ld",
          (unsigned long)data.length, tag);

    if (tag == kMyUltronPacketTagLength) {
        // We just read the 4-byte length prefix
        [self resetReadBuffer];
        [self.readBuffer appendData:data];

        if (data.length != kMyUltronPacketLengthByteCount) {
            NSLog(@"[MyUltron] Malformed length prefix");
            [self disconnectClient];
            return;
        }

        int32_t totalLen = *((const int32_t *)data.bytes);
        NSInteger remaining = totalLen - kMyUltronPacketLengthByteCount;
        if (remaining <= 0) {
            NSLog(@"[MyUltron] Invalid packet length: %d", totalLen);
            [self disconnectClient];
            return;
        }

        [self.clientSocket readDataToLength:remaining
                                withTimeout:-1
                                        tag:kMyUltronPacketTagContent];

    } else if (tag == kMyUltronPacketTagContent) {
        // We have the complete packet
        [self.readBuffer appendData:data];

        self.builder->decodePacket(self.readBuffer);
        myultron_packet_t *pkt = self.builder->getPacket();

        if (pkt == nullptr) {
            NSLog(@"[MyUltron] Failed to decode packet");
        } else {
            // Handle heartbeat internally
            if (pkt->header.packetType == MyUltronPacketTypePing) {
                [self sendPong];
            } else if ([self.delegate respondsToSelector:@selector(socket:didReceivePacket:)]) {
                [self.delegate socket:self didReceivePacket:pkt];
            }
        }

        [self resetReadBuffer];

        // Continue listening for the next packet
        [self.clientSocket readDataToLength:kMyUltronPacketLengthByteCount
                                withTimeout:-1
                                        tag:kMyUltronPacketTagLength];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
                  withError:(NSError *)err {
    if (sock != self.listenSocket) {
        NSLog(@"[MyUltron] Client disconnected: %@", err);
        self.clientSocket = nil;

        if ([self.delegate respondsToSelector:@selector(socketClientDidDisconnect:)]) {
            [self.delegate socketClientDidDisconnect:self];
        }
    }
}

- (void)disconnectClient {
    [self.clientSocket disconnect];
    self.clientSocket = nil;
}

@end
