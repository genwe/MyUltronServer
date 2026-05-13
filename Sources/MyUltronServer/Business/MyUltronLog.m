//
//  MyUltronLog.m
//  MyUltronServer
//
//  Redirects NSLog (stderr) to TCP for desktop log monitor.
//

#import "MyUltronLog.h"
#import "../MyUltronServer.h"
#include <unistd.h>

@interface MyUltronLog () <MyUltronServerMessageDelegate>
@property (nonatomic, weak) MyUltronServer *server;
@property (nonatomic, assign) int pipeFd;
@property (nonatomic, assign) int savedStderr;
@property (nonatomic, strong) NSFileHandle *readHandle;
@end

@implementation MyUltronLog

- (instancetype)initWithServer:(MyUltronServer *)server {
    self = [super init];
    if (self) {
        _server = server;
        [self startCapture];
    }
    return self;
}

- (void)dealloc {
    [self stopCapture];
}

- (void)startCapture {
    _savedStderr = dup(STDERR_FILENO);

    int fds[2];
    if (pipe(fds) != 0) return;
    _pipeFd = fds[1];

    dup2(fds[1], STDERR_FILENO);
    close(fds[1]);

    _readHandle = [[NSFileHandle alloc] initWithFileDescriptor:fds[0] closeOnDealloc:YES];

    __weak typeof(self) ws = self;
    _readHandle.readabilityHandler = ^(NSFileHandle *fh) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;

        NSData *data = [fh availableData];
        if (data.length == 0) return;

        // Echo to original stderr (Xcode console)
        write(ss->_savedStderr, data.bytes, data.length);

        NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!raw) return;

        for (NSString *line in [raw componentsSeparatedByString:@"\n"]) {
            NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (t.length == 0) continue;
            if (t.length > 500) t = [t substringToIndex:500];

            [ss.server sendMessage:@{
                kMyUltronMsgKeyVersion: @"1.0",
                kMyUltronMsgKeyType:    @"log",
                kMyUltronMsgKeyContent: @{@"message": t},
            }];
        }
    };
}

- (void)stopCapture {
    if (_readHandle) { _readHandle.readabilityHandler = nil; _readHandle = nil; }
    if (_savedStderr >= 0) {
        dup2(_savedStderr, STDERR_FILENO);
        close(_savedStderr);
        _savedStderr = -1;
    }
}

@end
