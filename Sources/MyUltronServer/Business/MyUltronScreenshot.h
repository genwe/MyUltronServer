//
//  MyUltronScreenshot.h
//  MyUltronServer
//
//  截屏模块 — 收到 screenshot 请求后截取当前 keyWindow 画面。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

@interface MyUltronScreenshot : NSObject

- (instancetype)initWithServer:(MyUltronServer *)server;

@end

NS_ASSUME_NONNULL_END
