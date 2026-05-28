//
//  MyUltronBasic.h
//  MyUltronServer
//
//  Basic handshake module.
//  Sends the library version to the client on connect.
//

#import <Foundation/Foundation.h>
#import "MyUltronModule.h"

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

/// Current MyUltronServer version.
extern NSString * const kMyUltronServerVersion;

@interface MyUltronBasic : NSObject <MyUltronModule>

- (instancetype)initWithServer:(MyUltronServer *)server;

@end

NS_ASSUME_NONNULL_END
