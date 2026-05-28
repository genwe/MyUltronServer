//
//  MyUltronManager.m
//  MyUltronServer
//
//  Manager singleton — owns the server and all built-in business modules.
//

#import "MyUltronManager.h"
#import "../MyUltronServer.h"
#import "../Business/MyUltronModule.h"
#import <objc/runtime.h>

@interface MyUltronManager ()

@property (nonatomic, strong, readwrite) MyUltronServer *server;
@property (nonatomic, strong) NSMutableArray<id<MyUltronModule>> *moduleInstances;

@end

@implementation MyUltronManager

#pragma mark - Module Discovery

// 通过 objc_getClassList 扫描所有遵循 MyUltronModule 协议的类
+ (NSArray<Class> *)discoverModuleClasses {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return @[];

    Class *allClasses = (Class *)malloc((unsigned)count * sizeof(Class));
    objc_getClassList(allClasses, count);

    NSMutableArray<Class> *result = [NSMutableArray array];
    Protocol *proto = @protocol(MyUltronModule);

    for (int i = 0; i < count; i++) {
        Class cls = allClasses[i];
        if (class_conformsToProtocol(cls, proto) && cls != [self class]) {
            [result addObject:cls];
        }
    }

    free(allClasses);
    return result;
}

#pragma mark - Singleton

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[MyUltronManager sharedInstance] start];
    });
}

+ (instancetype)sharedInstance {
    static MyUltronManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MyUltronManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _server = [[MyUltronServer alloc] initWithPort:62345];
        _moduleInstances = [NSMutableArray array];

        // 自动发现并实例化所有遵循 MyUltronModule 协议的类
        for (Class cls in [self.class discoverModuleClasses]) {
            id module = [[cls alloc] initWithServer:_server];
            if (module) [_moduleInstances addObject:module];
        }
    }
    return self;
}

- (void)dealloc {
    [self.server stopServer];
}

#pragma mark - Public API

- (void)start {
    [self.server startServer];
}

- (void)stop {
    [self.server stopServer];
}

- (void)applicationDidFinishLaunching {
    // Placeholder — extend for launch-time instrumentation.
}

- (void)applicationDidEnterBackground {
    [self.server appDidEnterBackground];
}

- (void)applicationWillEnterForeground {
    [self.server appWillEnterForeground];
}

@end
