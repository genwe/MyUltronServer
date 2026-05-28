//
//  MyUltronSandbox.h
//  MyUltronServer
//
//  沙盒管理模块 — list / create / delete app sandbox files.
//

#import <Foundation/Foundation.h>
#import "MyUltronModule.h"

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

@interface MyUltronSandbox : NSObject <MyUltronModule>

- (instancetype)initWithServer:(MyUltronServer *)server;

@end

NS_ASSUME_NONNULL_END
