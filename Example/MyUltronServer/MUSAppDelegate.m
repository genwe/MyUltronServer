//
//  MUSAppDelegate.m
//  MyUltronServer
//
//  Created by genwe on 05/06/2026.
//  Copyright (c) 2026 genwe. All rights reserved.
//

#import "MUSAppDelegate.h"
#import <MyUltronServer/MyUltronServer.h>
@import UserNotifications;

@interface MUSAppDelegate () <UNUserNotificationCenterDelegate>
@end

@implementation MUSAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // 注册通知授权 + 设置 delegate（前台展示推送弹窗）
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
                                             UNAuthorizationOptionSound |
                                             UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError *error) {
        if (granted) {
            NSLog(@"[MUSAppDelegate] 通知授权成功");
        } else {
            NSLog(@"[MUSAppDelegate] 通知授权失败: %@", error);
        }
    }];
    center.delegate = self;

    [MyUltronManager sharedInstance].extraAppInfo = ^NSDictionary *{
        return @{
            @"exampleKey": @"exampleValue",
        };
    };

    return YES;
}

// MARK: - UNUserNotificationCenterDelegate (前台弹窗)

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    // 前台也弹横幅 + 声音 + badge
    if (@available(iOS 14.0, *)) {
        completionHandler(UNNotificationPresentationOptionBanner |
                          UNNotificationPresentationOptionSound |
                          UNNotificationPresentationOptionBadge);
    } else {
        completionHandler(UNNotificationPresentationOptionAlert |
                          UNNotificationPresentationOptionSound |
                          UNNotificationPresentationOptionBadge);
    }
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

// MARK: - Remote Notification（原生推送 & MyUltronMessagePush 模块模拟）

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    NSLog(@"[MUSAppDelegate] 收到远程推送: %@", userInfo);

    NSDictionary *aps = userInfo[@"aps"];
    NSDictionary *alert = aps[@"alert"];

    // 发本地通知模拟系统推送弹窗（前台也能看到）
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title    = [alert[@"title"] isKindOfClass:[NSString class]] ? alert[@"title"] : @"";
    content.body     = [alert[@"body"]  isKindOfClass:[NSString class]] ? alert[@"body"]  : @"";
    content.sound    = [aps[@"sound"] isKindOfClass:[NSString class]]
                        ? [UNNotificationSound defaultSound]
                        : nil;
    content.badge    = aps[@"badge"];

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                          content:content
                                                                          trigger:nil];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                           withCompletionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"[MUSAppDelegate] 推送弹窗失败: %@", error);
        } else {
            NSLog(@"[MUSAppDelegate] 推送弹窗已展示");
        }
    }];
}

@end
