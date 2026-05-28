//
//  MyUltronLog.h
//  MyUltronServer
//

#import <Foundation/Foundation.h>
#import "MyUltronModule.h"

@class MyUltronServer;

@interface MyUltronLog : NSObject <MyUltronModule>

- (instancetype)initWithServer:(MyUltronServer *)server;

@end
