//
//  MyUltronUserDefaults.h
//  MyUltronServer
//
//  NSUserDefaults inspector — browse, set, delete keys.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

@interface MyUltronUserDefaults : NSObject

- (instancetype)initWithServer:(MyUltronServer *)server;

@end

NS_ASSUME_NONNULL_END
