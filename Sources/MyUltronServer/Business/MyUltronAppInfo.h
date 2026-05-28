//
//  MyUltronAppInfo.h
//  MyUltronServer
//
//  Application information module.
//  Responds to the "appInfo" message type with host-app metadata.
//

#import <Foundation/Foundation.h>
#import "MyUltronModule.h"

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

@interface MyUltronAppInfo : NSObject <MyUltronModule>

- (instancetype)initWithServer:(MyUltronServer *)server;

@end

NS_ASSUME_NONNULL_END
