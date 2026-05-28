//
//  MyUltronMessagePush.h
//  MyUltronServer
//
//  模拟远程推送模块 — 收到 Mac 客户端的推送 payload 后，
//  直接调用 AppDelegate 的 application:didReceiveRemoteNotification: 方法。
//

#import <Foundation/Foundation.h>
#import "MyUltronModule.h"

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

@interface MyUltronMessagePush : NSObject <MyUltronModule>

- (instancetype)initWithServer:(MyUltronServer *)server;

@end

NS_ASSUME_NONNULL_END
