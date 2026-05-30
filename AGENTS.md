# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project overview

MyUltronServer is an embeddable TCP debug server library for iOS apps (iOS 13+, ObjC/ObjC++). It communicates with the **MyUltron macOS desktop client** via a custom usbmux-compatible binary protocol on port **62345**. The companion macOS client lives in `MyUltron/MyUltron/` (a separate Xcode project).

## Build & distribution

This library supports two distribution channels:

**CocoaPods** (primary, version 0.1.5):
```ruby
pod 'MyUltronServer'
```
The podspec sources all `.h/.m/.mm` under `Sources/MyUltronServer/`. The Example app at `Example/` is a vanilla CocoaPods example project — open `Example/MyUltronServer.xcworkspace` to build and run it.

**Swift Package Manager**:
```swift
// Package.swift
.library(name: "MyUltronServer", targets: ["MyUltronServer"])
```
SPM builds define `SPM_BUILD` (see `Package.swift` `cxxSettings`). The only dependency is `CocoaAsyncSocket ~> 7.6`.

**Build requirements:** Xcode 14+, C++14 (`CLANG_CXX_LANGUAGE_STANDARD`).

## Architecture

```
MyUltronManager (singleton, lifecycle, owns all modules)
  └── MyUltronServer (message routing, delegate registry, send/receive API)
        └── MyUltronSocket (GCDAsyncSocket-based TCP listen/accept/framing)
              └── MyUltronPacketBuilder (C++ class, binary packet encode/decode)
                    └── MyUltronPacket.h (C structs: header + flexible payload)
```

All source files live under `Sources/MyUltronServer/`:

| Directory | Purpose |
|---|---|
| `Core/` | C packet struct (`MyUltronPacket.h`) and C++ builder (`MyUltronPacketBuilder.mm`) |
| `Socket/` | TCP layer (`MyUltronSocket.mm`) — uses GCDAsyncSocket, 4-byte length-prefixed framing |
| `Manager/` | `MyUltronManager` — singleton, auto-starts on `+load`, owns built-in business modules |
| `Business/` | Built-in message handlers: `MyUltronBasic`, `MyUltronAppInfo`, `MyUltronSandbox`, `MyUltronUserDefaults`, `MyUltronSqlite`, `MyUltronLog`, `MyUltronScreenshot` |
| `include/` | Umbrella header — the single public import for consumers |

**Key patterns:**
- `MyUltronServer` uses a `messageType`-based delegate routing system. Each business module registers for a type string (e.g. `"sandboxList"`, `"sqliteQuery"`) via `registerForMessageType:delegate:`.
- The binary protocol has a 16-byte header (`length/version/packetType/tag` in `int32_t`) followed by a payload. Packet types: Ping(1010), Pong(1020), TextMessage(1110), BinaryMessage(1120), JsonMessage(1130).
- Auto-start: `MyUltronManager.+load` schedules a 1-second delay then calls `-start`. Remove that `+load` override if manual start is preferred.
- Threading: socket I/O runs on a dedicated serial queue. Delegates are called on that queue.

## Adding a new business module

1. Create `Business/MyUltronFoo.h` and `Business/MyUltronFoo.m`
2. Conform to `<MyUltronServerMessageDelegate>`, take a `MyUltronServer *` in init, and call `[server registerForMessageType:@"foo" delegate:self]`
3. Implement `-myUltronServerDidReceiveMessage:` — parse `dict[kMyUltronMsgKeyContent]`, handle it, send responses via `[self.server sendMessage:@{...}]`
4. Register the module in `MyUltronManager.m` init

## Nested project

- **`MyUltron/`** — The macOS desktop debugging client (separate git repo). Connects to an iOS device via USB (libimobiledevice + usbmuxd) or simulator (localhost TCP). Has its own `.git`, build system, and settings.

## Screenshot architecture

`DeviceScreenshotViewController` (Mac) sends a `{ messageType: "screenshot" }` JSON request over the TCP connection. The iOS-side `MyUltronScreenshot` module receives it, captures the app's keyWindow using `UIGraphicsImageRenderer`, and returns the image as a PNG binary packet via `sendBinaryData:`. The Mac side's `didReceiveBinaryData:` converts it to `NSImage` for display.

This approach does **not** require Developer Disk Image or Xcode — only the iOS app with MyUltronServer integrated needs to be running and connected.

## Code conventions

- ObjC prefix: `MyUltron*` for all classes
- Public headers are in `Sources/MyUltronServer/include/` plus `Manager/MyUltronManager.h`
- `.mm` files for ObjC++ (Socket, PacketBuilder), `.m` for plain ObjC
- Constants: `kMyUltronMsgKeyVersion`, `kMyUltronMsgKeyType`, `kMyUltronMsgKeyContent` in `MyUltronServer.h`
