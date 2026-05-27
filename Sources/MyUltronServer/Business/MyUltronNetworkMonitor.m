//
//  MyUltronNetworkMonitor.m
//  MyUltronServer
//
//  通过 NSURLProtocol 拦截 HTTP/HTTPS 请求，记录 method/URL/status/duration，
//  Mac 端通过 TCP 定时拉取或实时推送请求列表。
//

#import "MyUltronNetworkMonitor.h"
#import "../MyUltronServer.h"
#import "../Manager/MyUltronManager.h"
#import <UIKit/UIKit.h>

// MARK: - Data Model

@interface ULNetworkEntry : NSObject
@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSUInteger requestSize;
@property (nonatomic, assign) NSUInteger responseSize;
@property (nonatomic, copy) NSString *requestHeaders;
@property (nonatomic, copy) NSString *requestBody;
@property (nonatomic, copy) NSString *requestQuery;
@property (nonatomic, copy) NSString *responseHeaders;
@property (nonatomic, copy) NSString *responseBody;
@property (nonatomic, copy) NSDate   *timestamp;
- (NSDictionary *)toDict;
@end

@implementation ULNetworkEntry
- (NSDictionary *)toDict {
    return @{
        @"id":              _requestID ?: @"",
        @"method":          _method ?: @"",
        @"url":             _url ?: @"",
        @"statusCode":      @(_statusCode),
        @"duration":        @(_duration),
        @"requestSize":     @(_requestSize),
        @"responseSize":    @(_responseSize),
        @"requestHeaders":  _requestHeaders ?: @"",
        @"requestBody":     _requestBody ?: @"",
        @"requestQuery":    _requestQuery ?: @"",
        @"responseHeaders": _responseHeaders ?: @"",
        @"responseBody":    _responseBody ?: @"",
        @"timestamp":       @(_timestamp.timeIntervalSince1970),
    };
}
@end

// MARK: - NSURLProtocol Subclass

@interface ULNetworkProtocol : NSURLProtocol <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, strong) NSURLResponse *savedResponse;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, assign) NSUInteger requestBodySize;
@end

// Shared state
static BOOL _monitoring = NO;

@implementation ULNetworkProtocol

+ (void)load {
    [NSURLProtocol registerClass:self];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (!_monitoring) return NO;
    if (![request.URL.scheme isEqualToString:@"http"] &&
        ![request.URL.scheme isEqualToString:@"https"]) return NO;
    if ([NSURLProtocol propertyForKey:@"ULMonitored" inRequest:request]) return NO;
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *mutableRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"ULMonitored" inRequest:mutableRequest];

    self.startTime = [NSDate date];
    self.requestBodySize = self.request.HTTPBody.length;
    self.mutableData = [NSMutableData data];

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:nil];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:mutableRequest];
    [task resume];
}

- (void)stopLoading {
    // NSURLSession tasks can't be stopped once started (simplification)
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    [self.mutableData appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    self.savedResponse = response;
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:self.startTime];

    NSHTTPURLResponse *httpResp = [self.savedResponse isKindOfClass:[NSHTTPURLResponse class]]
                                   ? (NSHTTPURLResponse *)self.savedResponse : nil;

    ULNetworkEntry *entry = [[ULNetworkEntry alloc] init];
    entry.requestID  = [[NSUUID UUID] UUIDString];
    entry.method     = self.request.HTTPMethod ?: @"GET";
    entry.url        = self.request.URL.absoluteString ?: @"";
    entry.statusCode = httpResp.statusCode;
    entry.duration   = duration;
    entry.requestSize = self.requestBodySize;
    entry.responseSize = self.mutableData.length;
    entry.timestamp  = [NSDate date];

    // Headers (truncated for readability)
    NSData *reqHeaderData = [NSJSONSerialization dataWithJSONObject:self.request.allHTTPHeaderFields ?: @{}
                                                            options:NSJSONWritingPrettyPrinted error:nil];
    entry.requestHeaders = [[NSString alloc] initWithData:reqHeaderData encoding:NSUTF8StringEncoding] ?: @"{}";

    NSData *respHeaderData = [NSJSONSerialization dataWithJSONObject:httpResp.allHeaderFields ?: @{}
                                                             options:NSJSONWritingPrettyPrinted error:nil];
    entry.responseHeaders = [[NSString alloc] initWithData:respHeaderData encoding:NSUTF8StringEncoding] ?: @"{}";

    // Query params
    entry.requestQuery = self.request.URL.query ?: @"";

    // Request body (截断 4KB)
    if (self.request.HTTPBody.length > 0) {
        NSString *bodyStr = [[NSString alloc] initWithData:self.request.HTTPBody encoding:NSUTF8StringEncoding];
        if (!bodyStr) bodyStr = [self.request.HTTPBody base64EncodedStringWithOptions:0];
        entry.requestBody = bodyStr.length > 4096 ? [[bodyStr substringToIndex:4096] stringByAppendingString:@"...(truncated)"] : bodyStr;
    } else {
        entry.requestBody = @"";
    }

    // Response body (截断 4KB)
    if (self.mutableData.length > 0) {
        NSString *respStr = [[NSString alloc] initWithData:self.mutableData encoding:NSUTF8StringEncoding];
        if (!respStr) respStr = [self.mutableData base64EncodedStringWithOptions:0];
        entry.responseBody = respStr.length > 4096 ? [[respStr substringToIndex:4096] stringByAppendingString:@"...(truncated)"] : respStr;
    } else {
        entry.responseBody = @"";
    }

    // 通过 TCP 实时推送到 Mac 端（不存储，不累积）
    if (_monitoring) {
        MyUltronServer *server = [MyUltronManager sharedInstance].server;
        if (server) {
            [server sendMessage:@{
                kMyUltronMsgKeyVersion: @"1.0",
                kMyUltronMsgKeyType:    @"networkMonitor",
                kMyUltronMsgKeyContent: @{
                    @"action": @"push",
                    @"entry": [entry toDict],
                },
            }];
        }
    }

    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
}

@end

// MARK: - MyUltronNetworkMonitor

@interface MyUltronNetworkMonitor () <MyUltronServerMessageDelegate>
@property (nonatomic, weak) MyUltronServer *server;
@end

@implementation MyUltronNetworkMonitor

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;
        _monitoring = YES; // 默认开启监控
        [server registerForMessageType:@"networkMonitor" delegate:self];
        NSLog(@"[MyUltron] NetworkMonitor module registered");
    }
    return self;
}

#pragma mark - MyUltronServerMessageDelegate

- (void)myUltronServerDidReceiveMessage:(NSDictionary *)dict {
    NSString *type = dict[kMyUltronMsgKeyType];
    NSDictionary *content = dict[kMyUltronMsgKeyContent];
    NSString *action = content[@"action"];

    if ([type isEqualToString:@"networkMonitor"]) {
        if ([action isEqualToString:@"start"]) {
            _monitoring = YES;
            [self replyWithSuccess:YES];
        } else if ([action isEqualToString:@"stop"]) {
            _monitoring = NO;
            [self replyWithSuccess:YES];
        }
    }
}

- (void)replyWithSuccess:(BOOL)success {
    [self.server sendMessage:@{
        kMyUltronMsgKeyVersion: @"1.0",
        kMyUltronMsgKeyType:    @"networkMonitor",
        kMyUltronMsgKeyContent: @{
            @"success": @(success),
            @"monitoring": @(_monitoring),
        },
    }];
}

@end
