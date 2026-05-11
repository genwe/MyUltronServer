//
//  MUSSceneDelegate.m
//  MyUltronServer
//
//  Forwards UIScene lifecycle events to MyUltronManager.
//

#import "MUSSceneDelegate.h"
#import <MyUltronServer/MyUltronServer.h>

@implementation MUSSceneDelegate

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions
{
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self.window.rootViewController = [storyboard instantiateInitialViewController];
    [self.window makeKeyAndVisible];
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    [[MyUltronManager sharedInstance] applicationDidEnterBackground];
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    [[MyUltronManager sharedInstance] applicationWillEnterForeground];
}

@end
