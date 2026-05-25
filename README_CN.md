# MyUltronServer

[![Version](https://img.shields.io/cocoapods/v/MyUltronServer.svg?style=flat)](https://cocoapods.org/pods/MyUltronServer)
[![License](https://img.shields.io/cocoapods/l/MyUltronServer.svg?style=flat)](https://cocoapods.org/pods/MyUltronServer)
[![Platform](https://img.shields.io/cocoapods/p/MyUltronServer.svg?style=flat)](https://cocoapods.org/pods/MyUltronServer)

可嵌入 iOS 应用的 TCP 调试服务端。通过自定义二进制协议，在宿主应用与 **MyUltron 桌面客户端** 之间建立实时双向通信。

## 架构

```
 MyUltron 桌面客户端
          │
    TCP（自定义二进制协议）
          │
 ┌────────▼────────────────────────────┐
 │       MyUltronServer（宿主 App）     │
 │                                      │
 │  ┌────────────────────────────────┐  │
 │  │     MyUltronManager            │  │
 │  │  （单例、生命周期管理、初始化）   │  │
 │  └──────────┬─────────────────────┘  │
 │             │                        │
 │  ┌──────────▼─────────────────────┐  │
 │  │     MyUltronServer             │  │
 │  │  （消息路由、委托分发）          │  │
 │  └──────────┬─────────────────────┘  │
 │             │                        │
 │  ┌──────────▼─────────────────────┐  │
 │  │     MyUltronSocket             │  │
 │  │  （TCP 监听/接收、数据帧解析）   │  │
 │  └──────────┬─────────────────────┘  │
 │             │                        │
 │  ┌──────────▼─────────────────────┐  │
 │  │  MyUltronPacketBuilder (C++)   │  │
 │  │  （二进制包编解码）              │  │
 │  └────────────────────────────────┘  │
 │                                      │
 │  业务模块：                           │
 │   • MyUltronBasic   （握手）          │
 │   • MyUltronAppInfo （应用信息）       │
 │   • MyUltronSandbox （文件操作）       │
 │   • MyUltronUserDefaults（偏好设置）   │
 │   • MyUltronSqlite   （数据库浏览）    │
 │   • MyUltronLog      （日志捕获）      │
 └──────────────────────────────────────┘
```

### 文件结构

```
Sources/MyUltronServer/
├── include/
│   └── MyUltronServer.h            # 公开入口头文件
├── MyUltronServer.h                # 服务端类及委托协议
├── MyUltronServer.m                # 服务端：原始包 → JSON → 委托路由
├── Core/
│   ├── MyUltronPacket.h            # C 数据包结构体 / 类型枚举
│   ├── MyUltronPacketBuilder.h     # C++ 编解码接口
│   └── MyUltronPacketBuilder.mm    # C++ 实现
├── Socket/
│   ├── MyUltronSocket.h            # TCP 监听 / 接收 / 数据帧解析
│   └── MyUltronSocket.mm           # 基于 GCDAsyncSocket 的实现（ObjC++）
├── Manager/
│   ├── MyUltronManager.h           # 公开单例及生命周期 API
│   └── MyUltronManager.m           # 模块初始化、自动启动
├── Business/
│   ├── MyUltronBasic.h / .m        # 客户端连接时握手
│   ├── MyUltronAppInfo.h / .m      # 应用元信息（响应 "appInfo"）
│   ├── MyUltronSandbox.h / .m      # 沙盒文件操作（列举/创建/删除）
│   ├── MyUltronUserDefaults.h / .m # NSUserDefaults 查看器（浏览/设置/删除）
│   ├── MyUltronSqlite.h / .m       # SQLite 查看器（列举库、浏览表、增删改查）
│   └── MyUltronLog.h / .m          # 日志捕获与转发
```

### 消息类型

| messageType | 模块 | 方向 | 说明 |
|---|---|---|---|
| `ultron` | MyUltronBasic | 服务端 → 客户端 | 连接时握手 |
| `appInfo` | MyUltronAppInfo | 双向 | 宿主应用元信息 |
| `sandboxList` | MyUltronSandbox | 双向 | 列举沙盒目录 |
| `sandboxCreateDir` | MyUltronSandbox | 双向 | 创建沙盒目录 |
| `sandboxDelete` | MyUltronSandbox | 双向 | 删除沙盒文件/目录 |
| `sandboxDownload` | MyUltronSandbox | 双向 | 下载沙盒文件 |
| `userDefaultsList` | MyUltronUserDefaults | 双向 | 列举 UserDefaults 键 |
| `userDefaultsSet` | MyUltronUserDefaults | 双向 | 设置 UserDefaults 值 |
| `userDefaultsDelete` | MyUltronUserDefaults | 双向 | 删除 UserDefaults 键 |
| `sqliteList` | MyUltronSqlite | 双向 | 列举 SQLite 数据库 |
| `sqliteQuery` | MyUltronSqlite | 双向 | 执行 SQL 查询 |
| `logStart` | MyUltronLog | 客户端 → 服务端 | 开始日志捕获 |
| `logStop` | MyUltronLog | 客户端 → 服务端 | 停止日志捕获 |
| `logMessage` | MyUltronLog | 服务端 → 客户端 | 转发日志行 |

## 协议

MyUltronServer 使用 **兼容 usbmux 的二进制数据包格式**：

```
┌──────────────────────────────────────────────┐
│ 包头（16 字节）                                │
│  - int32_t length      （数据包总长度）          │
│  - int32_t version     （协议版本）             │
│  - int32_t packetType  （消息类型）             │
│  - int32_t tag         （请求/响应 ID）         │
├──────────────────────────────────────────────┤
│ 载荷（length - 16 字节）                       │
└──────────────────────────────────────────────┘
```

**数据包类型：**

| 类型 | 值 | 说明 |
|------|-------|-------------|
| Ping | 1010 | 心跳请求 |
| Pong | 1020 | 心跳响应 |
| TextMessage | 1110 | UTF-8 文本 |
| BinaryMessage | 1120 | 原始二进制数据 |
| JsonMessage | 1130 | JSON 字典 |

**JSON 消息格式：**

```json
{
  "version": "1.0",
  "messageType": "appInfo",
  "content": { ... }
}
```

## 集成

### CocoaPods

```ruby
pod 'MyUltronServer'
```

### AppDelegate 配置

```objc
// AppDelegate.m
#import <MyUltronServer/MyUltronServer.h>

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // 服务端在 +load 时自动启动，无需显式调用 -start。
    // 如需手动控制，可显式调用。
    [[MyUltronManager sharedInstance] start];

    // 可选：提供额外的应用信息
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

完成以上配置即可 — 服务端监听端口 **62345**。

## 扩展：自定义业务模块

添加自己的消息处理器：

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
    // 处理消息...

    // 发送响应
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"myCustomType",
        kMyUltronMsgKeyContent: @{@"reply": @"ok"},
    }];
}

@end
```

然后在 AppDelegate（或其他模块管理位置）初始化：

```objc
MyUltronServer *server = [MyUltronManager sharedInstance].server;
MyCustomModule *module = [[MyCustomModule alloc] initWithServer:server];
```

## 系统要求

- iOS 13.0+
- Xcode 14+
- CocoaAsyncSocket ~> 7.6（作为 pod 依赖包含）

## 作者

genwe, weareroot@163.com

## 许可证

MyUltronServer 基于 MIT 许可证开源。详见 LICENSE 文件。
