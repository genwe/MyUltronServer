//
//  MUSAppDelegate.m
//  MyUltronServer
//
//  Created by genwe on 05/06/2026.
//  Copyright (c) 2026 genwe. All rights reserved.
//

#import "MUSAppDelegate.h"
#import <MyUltronServer/MyUltronServer.h>

@implementation MUSAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // MyUltronServer auto-starts on +load (1 s delay).
    // You can also call -start explicitly for fine-grained control:
    //
    //   [[MyUltronManager sharedInstance] start];

    // Optional: attach extra app info visible in the MyUltron desktop client.
    [MyUltronManager sharedInstance].extraAppInfo = ^NSDictionary *{
        return @{
            @"exampleKey": @"exampleValue",
        };
    };

    return YES;
}

// MARK: - UIScene Configuration

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                options:(UISceneConnectionOptions *)options
{
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                          sessionRole:connectingSceneSession.role];
}

// MARK: - App-level lifecycle (fallback for older patterns)

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[MyUltronManager sharedInstance] applicationDidEnterBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[MyUltronManager sharedInstance] applicationWillEnterForeground];
}

@end
