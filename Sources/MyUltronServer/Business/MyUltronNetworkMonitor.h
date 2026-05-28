//
//  MyUltronNetworkMonitor.h
//  MyUltronServer
//
//  网络监控模块 — 通过 NSURLProtocol 拦截 HTTP 请求，记录并回传数据。
//

#import <Foundation/Foundation.h>
#import "MyUltronModule.h"

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

@interface MyUltronNetworkMonitor : NSObject <MyUltronModule>

- (instancetype)initWithServer:(MyUltronServer *)server;

@end

NS_ASSUME_NONNULL_END
