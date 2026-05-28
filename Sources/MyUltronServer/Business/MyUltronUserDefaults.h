//
//  MyUltronUserDefaults.h
//  MyUltronServer
//
//  NSUserDefaults inspector — browse, set, delete keys.
//

#import <Foundation/Foundation.h>
#import "MyUltronModule.h"

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

@interface MyUltronUserDefaults : NSObject <MyUltronModule>

- (instancetype)initWithServer:(MyUltronServer *)server;

@end

NS_ASSUME_NONNULL_END
