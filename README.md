# MyUltronServer

[![Version](https://img.shields.io/cocoapods/v/MyUltronServer.svg?style=flat)](https://cocoapods.org/pods/MyUltronServer)
[![License](https://img.shields.io/cocoapods/l/MyUltronServer.svg?style=flat)](https://cocoapods.org/pods/MyUltronServer)
[![Platform](https://img.shields.io/cocoapods/p/MyUltronServer.svg?style=flat)](https://cocoapods.org/pods/MyUltronServer)

An embeddable TCP debug server for iOS apps. MyUltronServer enables real-time two-way communication between a host iOS application and the **MyUltron desktop client** via a custom binary protocol.

## Architecture

```
 MyUltron Desktop Client
          │
    TCP (custom binary protocol)
          │
 ┌────────▼────────────────────────────┐
 │       MyUltronServer (Host App)      │
 │                                      │
 │  ┌────────────────────────────────┐  │
 │  │     MyUltronManager            │  │
 │  │  (singleton, lifecycle, init)  │  │
 │  └──────────┬─────────────────────┘  │
 │             │                        │
 │  ┌──────────▼─────────────────────┐  │
 │  │     MyUltronServer             │  │
 │  │  (message routing, delegates)  │  │
 │  └──────────┬─────────────────────┘  │
 │             │                        │
 │  ┌──────────▼─────────────────────┐  │
 │  │     MyUltronSocket             │  │
 │  │  (TCP listen/accept, framing)  │  │
 │  └──────────┬─────────────────────┘  │
 │             │                        │
 │  ┌──────────▼─────────────────────┐  │
 │  │  MyUltronPacketBuilder (C++)   │  │
 │  │  (encode/decode binary packet) │  │
 │  └────────────────────────────────┘  │
 │                                      │
 │  Business Modules:                   │
 │   • MyUltronBasic   (handshake)      │
 │   • MyUltronAppInfo (app metadata)   │
 │   • Your custom modules ...          │
 └──────────────────────────────────────┘
```

### File Structure

```
Sources/MyUltronServer/
├── include/
│   └── MyUltronServer.h            # Umbrella header (public entry point)
├── MyUltronServer.h                # Server class & delegate protocol
├── MyUltronServer.m                # Server: raw-packet → JSON → delegate routing
├── Core/
│   ├── MyUltronPacket.h            # C packet struct / type enums
│   ├── MyUltronPacketBuilder.h     # C++ encode/decode interface
│   └── MyUltronPacketBuilder.mm    # C++ implementation
├── Socket/
│   ├── MyUltronSocket.h            # TCP listen / accept / framing
│   └── MyUltronSocket.mm           # GCDAsyncSocket-based implementation (ObjC++)
├── Manager/
│   ├── MyUltronManager.h           # Public singleton & lifecycle API
│   └── MyUltronManager.m           # Module initialization, auto-start
├── Business/
│   ├── MyUltronBasic.h / .m        # Handshake on client connect
│   └── MyUltronAppInfo.h / .m      # App metadata (responds to "appInfo")
```

## Protocol

MyUltronServer uses a **usbmux-compatible binary packet format**:

```
┌──────────────────────────────────────────────┐
│ Header (16 bytes)                            │
│  - int32_t length      (total packet size)   │
│  - int32_t version     (protocol version)    │
│  - int32_t packetType  (message type)        │
│  - int32_t tag         (request/response id) │
├──────────────────────────────────────────────┤
│ Payload (length - 16 bytes)                  │
└──────────────────────────────────────────────┘
```

**Packet Types:**

| Type | Value | Description |
|------|-------|-------------|
| Ping | 1010 | Heartbeat request |
| Pong | 1020 | Heartbeat response |
| TextMessage | 1110 | UTF-8 text |
| BinaryMessage | 1120 | Raw binary data |
| JsonMessage | 1130 | JSON dictionary |

**JSON Message Format:**

```json
{
  "version": "1.0",
  "messageType": "appInfo",
  "content": { ... }
}
```

## Integration

### CocoaPods

```ruby
pod 'MyUltronServer'
```

### AppDelegate Setup

```objc
// AppDelegate.m
#import <MyUltronServer/MyUltronServer.h>

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Server auto-starts on +load — no explicit -start needed.
    // But you can call it explicitly for control.
    [[MyUltronManager sharedInstance] start];

    // Optional: provide extra app info
    [MyUltronManager sharedInstance].extraAppInfo = ^NSDictionary *{
        return @{
            @"customKey": @"customValue",
        };
    };

    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[MyUltronManager sharedInstance] applicationDidEnterBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [[MyUltronManager sharedInstance] applicationWillEnterForeground];
}
```

That's it — the server listens on port **62345** (or **72345** for Debug/Ad-Hoc builds).

## Extending: Custom Business Modules

Add your own message handlers:

```objc
// MyCustomModule.m
#import <MyUltronServer/MyUltronServer.h>

@interface MyCustomModule () <MyUltronServerMessageDelegate>
@property (nonatomic, weak) MyUltronServer *server;
@end

@implementation MyCustomModule

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;
        [server registerForMessageType:@"myCustomType" delegate:self];
    }
    return self;
}

- (void)myUltronServerDidReceiveMessage:(NSDictionary *)dict {
    NSDictionary *content = dict[kMyUltronMsgKeyContent];
    // Handle the message...

    // Send a response
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"myCustomType",
        kMyUltronMsgKeyContent: @{@"reply": @"ok"},
    }];
}

@end
```

Then initialize it in your AppDelegate (or wherever you manage modules):

```objc
MyUltronServer *server = [MyUltronManager sharedInstance].server;
MyCustomModule *module = [[MyCustomModule alloc] initWithServer:server];
```

## Requirements

- iOS 13.0+
- Xcode 14+
- CocoaAsyncSocket ~> 7.6 (included as pod dependency)

## Author

genwe, weareroot@163.com

## License

MyUltronServer is available under the MIT license. See the LICENSE file for more info.
