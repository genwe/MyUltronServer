//
//  MyUltronScreenshot.m
//  MyUltronServer
//
//  收到 Mac 客户端的截图请求 → 在主线程截取 keyWindow → PNG → 二进制回传。
//

#import "MyUltronScreenshot.h"
#import "../MyUltronServer.h"
#import <UIKit/UIKit.h>

@interface MyUltronScreenshot () <MyUltronServerMessageDelegate>

@property (nonatomic, weak) MyUltronServer *server;

@end

@implementation MyUltronScreenshot

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;
        [server registerForMessageType:@"screenshot" delegate:self];
        NSLog(@"[MyUltron] Screenshot module registered");
    }
    return self;
}

#pragma mark - MyUltronServerMessageDelegate

- (void)myUltronServerDidReceiveMessage:(NSDictionary *)dict {
    NSLog(@"[MyUltron] Screenshot: received request");

    // 截屏必须在主线程（UIKit 不是线程安全的）
    dispatch_async(dispatch_get_main_queue(), ^{
        NSData *pngData = [self captureScreenAsPNG];
        if (pngData) {
            [self.server sendBinaryData:pngData];
            NSLog(@"[MyUltron] Screenshot sent: %lu bytes", (unsigned long)pngData.length);
        } else {
            NSLog(@"[MyUltron] Screenshot: failed to capture screen");
        }
    });
}

#pragma mark - Capture

- (nullable NSData *)captureScreenAsPNG {
    UIWindow *window = [self keyWindow];
    if (!window) {
        NSLog(@"[MyUltron] Screenshot: no key window found");
        return nil;
    }

    UIGraphicsImageRendererFormat *format = [[UIGraphicsImageRendererFormat alloc] init];
    format.scale = window.screen.scale;
    format.opaque = YES;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:window.bounds.size
                                                                               format:format];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }];

    return UIImagePNGRepresentation(image);
}

- (nullable UIWindow *)keyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *w in windowScene.windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    // 兼容旧版 API
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
}

@end
