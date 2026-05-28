//
//  MyUltronModule.h
//  MyUltronServer
//
//  业务模块协议。任何类遵循此协议并实现 -initWithServer: 后，
//  MyUltronManager 在启动时会通过 objc_getClassList 自动发现并实例化，
//  无需手动注册。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MyUltronServer;

@protocol MyUltronModule <NSObject>

/// 使用给定的 server 实例初始化模块。
/// 模块应在 init 中通过 [server registerForMessageType:delegate:self] 注册感兴趣的消息类型。
- (instancetype)initWithServer:(MyUltronServer *)server;

@end

/// 扫描所有运行时类，返回遵循 MyUltronModule 协议的类（不含抽象/内部类）。
/// 过滤掉 NSObject/ MyUltronManager 等基础类以及内部嵌套类。
NSArray<Class> *MyUltronModuleClasses(void);

NS_ASSUME_NONNULL_END
