//
//  MyUltronMessagePush.m
//  MyUltronServer
//
//  收到 Mac 客户端的推送 JSON payload → 调用 AppDelegate 的
//  application:didReceiveRemoteNotification: 模拟远程推送到达。
//

#import "MyUltronMessagePush.h"
#import "../MyUltronServer.h"
#import <UIKit/UIKit.h>


@interface MyUltronMessagePush () <MyUltronServerMessageDelegate>
@property (nonatomic, weak) MyUltronServer *server;
@end

@implementation MyUltronMessagePush

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;
        [server registerForMessageType:@"messagePush" delegate:self];
        NSLog(@"[MyUltron] MessagePush module registered");
    }
    return self;
}

#pragma mark - MyUltronServerMessageDelegate

- (void)myUltronServerDidReceiveMessage:(NSDictionary *)dict {
    NSDictionary *payload = dict[kMyUltronMsgKeyContent];
    if (![payload isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[MyUltron] MessagePush: invalid payload");
        [self replyWithSuccess:NO error:@"payload must be a JSON object"];
        return;
    }

    NSLog(@"[MyUltron] MessagePush: simulating remote push with payload: %@", payload);

    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        id<UIApplicationDelegate> delegate = app.delegate;

        if ([delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:)]) {
            [delegate application:app didReceiveRemoteNotification:payload];
            [self replyWithSuccess:YES error:nil];
        } else if ([delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
            [delegate application:app didReceiveRemoteNotification:payload
                    fetchCompletionHandler:^(UIBackgroundFetchResult result) {}];
            [self replyWithSuccess:YES error:nil];
        } else {
            NSLog(@"[MyUltron] MessagePush: AppDelegate 未实现 didReceiveRemoteNotification:");
            [self replyWithSuccess:NO error:@"AppDelegate 未实现 didReceiveRemoteNotification:"];
        }
    });
}

- (void)replyWithSuccess:(BOOL)success error:(NSString *)error {
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"messagePush",
        kMyUltronMsgKeyContent: success ? @{@"success": @YES}
                                        : @{@"success": @NO, @"error": error ?: @"unknown"},
    }];
}

@end
