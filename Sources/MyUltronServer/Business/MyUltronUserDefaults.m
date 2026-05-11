//
//  MyUltronUserDefaults.m
//  MyUltronServer
//
//  Browse, set, and delete NSUserDefaults keys.
//

#import "MyUltronUserDefaults.h"
#import "../MyUltronServer.h"

@interface MyUltronUserDefaults () <MyUltronServerMessageDelegate>
@property (nonatomic, weak) MyUltronServer *server;
@end

@implementation MyUltronUserDefaults

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;
        [server registerForMessageType:@"userDefaultsList"   delegate:self];
        [server registerForMessageType:@"userDefaultsSet"    delegate:self];
        [server registerForMessageType:@"userDefaultsDelete" delegate:self];
    }
    return self;
}

#pragma mark - Delegate

- (void)myUltronServerDidReceiveMessage:(NSDictionary *)dict {
    NSString *type = dict[kMyUltronMsgKeyType];
    NSDictionary *content = dict[kMyUltronMsgKeyContent];

    if ([type isEqualToString:@"userDefaultsList"]) {
        [self handleList];
    } else if ([type isEqualToString:@"userDefaultsSet"]) {
        [self handleSet:content];
    } else if ([type isEqualToString:@"userDefaultsDelete"]) {
        [self handleDelete:content];
    }
}

#pragma mark - List

- (void)handleList {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSDictionary<NSString *, id> *fullDict = [ud dictionaryRepresentation];
    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:fullDict.count];

    [fullDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        NSString *type = @"unknown";
        id jsonValue = [NSNull null];
        NSString *objClass = NSStringFromClass([obj class]);

        if ([obj isKindOfClass:[NSString class]]) {
            type = @"String";
            jsonValue = obj;
        } else if ([obj isKindOfClass:[NSNumber class]]) {
            if (CFGetTypeID((__bridge CFTypeRef)obj) == CFBooleanGetTypeID()) {
                type = @"Boolean";
                jsonValue = obj;
            } else {
                type = @"Number";
                jsonValue = obj;
            }
        } else if ([obj isKindOfClass:[NSDate class]]) {
            type = @"Date";
            jsonValue = @([(NSDate *)obj timeIntervalSince1970]);
        } else if ([obj isKindOfClass:[NSData class]]) {
            type = @"Data";
            jsonValue = [(NSData *)obj base64EncodedStringWithOptions:0];
        } else if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSDictionary class]]) {
            type = @"JSON";
            NSData *json = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
            jsonValue = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"{}";
        }

        // Preview: truncate long strings
        NSString *preview = [jsonValue isKindOfClass:[NSString class]]
            ? (NSString *)jsonValue
            : [jsonValue description];
        if (preview.length > 200) {
            preview = [[preview substringToIndex:200] stringByAppendingString:@"..."];
        }

        if ([type isEqualToString:@"unknown"]) {
            NSLog(@"[MyUltron] UD unknown: key=%@ class=%@", key, objClass);
        }

        [keys addObject:@{
            @"key":     key,
            @"type":    type,
            @"value":   jsonValue,
            @"preview": preview,
        }];
    }];

    [keys sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"key" ascending:YES]]];

    NSLog(@"[MyUltron] UserDefaults list: %lu keys (dict size=%lu)",
          (unsigned long)keys.count, (unsigned long)fullDict.count);

    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"userDefaultsList",
        kMyUltronMsgKeyContent: @{@"keys": keys},
    }];
}

#pragma mark - Set

- (void)handleSet:(NSDictionary *)content {
    NSString *key  = content[@"key"];
    NSString *type = content[@"type"] ?: @"String";
    id rawValue    = content[@"value"];

    if (key.length == 0 || rawValue == nil || [rawValue isKindOfClass:[NSNull class]]) {
        [self respondSet:NO];
        return;
    }

    NSString *strVal = [rawValue isKindOfClass:[NSString class]]
                        ? (NSString *)rawValue
                        : [rawValue description];

    id converted = strVal;
    if ([type isEqualToString:@"Number"]) {
        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
        nf.numberStyle = NSNumberFormatterDecimalStyle;
        converted = [nf numberFromString:strVal] ?: @0;
    } else if ([type isEqualToString:@"Boolean"]) {
        converted = @([strVal boolValue]);
    } else if ([type isEqualToString:@"Date"]) {
        converted = [NSDate dateWithTimeIntervalSince1970:[strVal doubleValue]];
    }

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:converted forKey:key];
    [ud synchronize];
    [self respondSet:YES];
}

- (void)respondSet:(BOOL)success {
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"userDefaultsSet",
        kMyUltronMsgKeyContent: @{@"success": @(success)},
    }];
}

#pragma mark - Delete

- (void)handleDelete:(NSDictionary *)content {
    NSString *key = content[@"key"];
    if (key.length == 0) {
        [self respondDelete:NO];
        return;
    }

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud removeObjectForKey:key];
    [ud synchronize];
    [self respondDelete:YES];
}

- (void)respondDelete:(BOOL)success {
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"userDefaultsDelete",
        kMyUltronMsgKeyContent: @{@"success": @(success)},
    }];
}

@end
