//
//  MUSViewController.m
//  MyUltronServer
//
//  Created by genwe on 05/06/2026.
//  Copyright (c) 2026 genwe. All rights reserved.
//

#import "MUSViewController.h"
#import <sqlite3.h>

@interface MUSViewController ()

@end

@implementation MUSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"key1"];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:@"发送网络请求" forState:UIControlStateNormal];
    button.frame = CGRectMake(0, 0, 200, 44);
    button.center = CGPointMake(self.view.bounds.size.width / 2,
                                self.view.bounds.size.height / 2);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                              UIViewAutoresizingFlexibleRightMargin |
                              UIViewAutoresizingFlexibleTopMargin |
                              UIViewAutoresizingFlexibleBottomMargin;
    [button addTarget:self
               action:@selector(sendNetworkRequests:)
     forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];

    [self setupDatabase];
}

- (void)setupDatabase {
    // 获取 Documents 目录
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dbPath = [docPath stringByAppendingPathComponent:@"User.db"];
    NSLog(@"数据库路径: %@", dbPath);

    sqlite3 *db = NULL;
    if (sqlite3_open(dbPath.UTF8String, &db) != SQLITE_OK) {
        NSLog(@"打开数据库失败: %s", sqlite3_errmsg(db));
        return;
    }

    char *errMsg = NULL;

    // 创建 user 表
    const char *createUserSQL =
        "CREATE TABLE IF NOT EXISTS user ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  姓名 TEXT,"
        "  性别 TEXT,"
        "  年龄 INTEGER"
        ");";
    if (sqlite3_exec(db, createUserSQL, NULL, NULL, &errMsg) != SQLITE_OK) {
        NSLog(@"创建 user 表失败: %s", errMsg);
        sqlite3_free(errMsg);
    } else {
        NSLog(@"user 表已就绪");

        // 插入张三的数据（仅在首次创建表时插入）
        const char *insertUserSQL = "INSERT INTO user (姓名, 性别, 年龄) SELECT '张三', '男', 35 WHERE NOT EXISTS (SELECT 1 FROM user WHERE 姓名='张三');";
        if (sqlite3_exec(db, insertUserSQL, NULL, NULL, &errMsg) != SQLITE_OK) {
            NSLog(@"插入 user 数据失败: %s", errMsg);
            sqlite3_free(errMsg);
        } else {
            NSLog(@"user 数据已插入: 张三, 男, 35");
        }
    }

    // 创建 work 表
    const char *createWorkSQL =
        "CREATE TABLE IF NOT EXISTS work ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  岗位名称 TEXT,"
        "  薪资 REAL"
        ");";
    if (sqlite3_exec(db, createWorkSQL, NULL, NULL, &errMsg) != SQLITE_OK) {
        NSLog(@"创建 work 表失败: %s", errMsg);
        sqlite3_free(errMsg);
    } else {
        NSLog(@"work 表已就绪");

        // 插入开发岗位数据（仅在首次创建表时插入）
        const char *insertWorkSQL = "INSERT INTO work (岗位名称, 薪资) SELECT '开发', 10000 WHERE NOT EXISTS (SELECT 1 FROM work WHERE 岗位名称='开发');";
        if (sqlite3_exec(db, insertWorkSQL, NULL, NULL, &errMsg) != SQLITE_OK) {
            NSLog(@"插入 work 数据失败: %s", errMsg);
            sqlite3_free(errMsg);
        } else {
            NSLog(@"work 数据已插入: 开发, 10000");
        }
    }

    sqlite3_close(db);
    NSLog(@"数据库初始化完成");
}

- (void)sendNetworkRequests:(UIButton *)sender {
    sender.enabled = NO;
    NSLog(@"[Sample] 开始发送网络请求...");

    NSURLSession *session = [NSURLSession sharedSession];

    // 1. GET - JSON API
    NSURL *url1 = [NSURL URLWithString:@"https://httpbin.org/get?name=ultron&version=1.0"];
    [[session dataTaskWithURL:url1 completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSLog(@"[Sample] GET httpbin.org/get done, status=%ld",
              (long)((NSHTTPURLResponse *)r).statusCode);
    }] resume];

    // 2. GET - HTTP Status 200
    NSURL *url2 = [NSURL URLWithString:@"https://httpbin.org/status/200"];
    [[session dataTaskWithURL:url2 completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSLog(@"[Sample] GET httpbin.org/status/200 done");
    }] resume];

    // 3. POST - JSON body
    NSURL *url3 = [NSURL URLWithString:@"https://httpbin.org/post"];
    NSMutableURLRequest *req3 = [NSMutableURLRequest requestWithURL:url3];
    req3.HTTPMethod = @"POST";
    req3.HTTPBody = [@"{\"device\":\"iPhone\",\"action\":\"test\"}" dataUsingEncoding:NSUTF8StringEncoding];
    [req3 setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [[session dataTaskWithRequest:req3 completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSLog(@"[Sample] POST httpbin.org/post done, status=%ld",
              (long)((NSHTTPURLResponse *)r).statusCode);
    }] resume];

    // 4. GET - 带自定义 Header
    NSURL *url4 = [NSURL URLWithString:@"https://httpbin.org/headers"];
    NSMutableURLRequest *req4 = [NSMutableURLRequest requestWithURL:url4];
    [req4 setValue:@"MyUltron/1.0" forHTTPHeaderField:@"X-Custom-Agent"];
    [req4 setValue:@"Bearer test-token-123" forHTTPHeaderField:@"Authorization"];
    [[session dataTaskWithRequest:req4 completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSLog(@"[Sample] GET httpbin.org/headers done");
    }] resume];

    // 5. POST - Form URL-Encoded
    NSURL *url5 = [NSURL URLWithString:@"https://httpbin.org/post"];
    NSMutableURLRequest *req5 = [NSMutableURLRequest requestWithURL:url5];
    req5.HTTPMethod = @"POST";
    NSString *body = @"username=iosdev&password=secret123";
    req5.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    [req5 setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [[session dataTaskWithRequest:req5 completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSLog(@"[Sample] POST httpbin.org/post (form) done, status=%ld",
              (long)((NSHTTPURLResponse *)r).statusCode);
    }] resume];

    // 1 秒后恢复按钮
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        sender.enabled = YES;
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
