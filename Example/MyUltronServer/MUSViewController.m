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
    [button setTitle:@"点击" forState:UIControlStateNormal];
    button.frame = CGRectMake(0, 0, 200, 44);
    button.center = CGPointMake(self.view.bounds.size.width / 2,
                                self.view.bounds.size.height / 2);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                              UIViewAutoresizingFlexibleRightMargin |
                              UIViewAutoresizingFlexibleTopMargin |
                              UIViewAutoresizingFlexibleBottomMargin;
    [button addTarget:self
               action:@selector(buttonTapped:)
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

//        // 插入张三的数据
//        const char *insertUserSQL = "INSERT INTO user (姓名, 性别, 年龄) VALUES ('张三', '男', 35);";
//        if (sqlite3_exec(db, insertUserSQL, NULL, NULL, &errMsg) != SQLITE_OK) {
//            NSLog(@"插入 user 数据失败: %s", errMsg);
//            sqlite3_free(errMsg);
//        } else {
//            NSLog(@"user 数据已插入: 张三, 男, 35");
//        }
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

//        // 插入开发岗位数据
//        const char *insertWorkSQL = "INSERT INTO work (岗位名称, 薪资) VALUES ('开发', 10000);";
//        if (sqlite3_exec(db, insertWorkSQL, NULL, NULL, &errMsg) != SQLITE_OK) {
//            NSLog(@"插入 work 数据失败: %s", errMsg);
//            sqlite3_free(errMsg);
//        } else {
//            NSLog(@"work 数据已插入: 开发, 10000");
//        }
    }

    sqlite3_close(db);
    NSLog(@"数据库初始化完成");
}

- (void)buttonTapped:(UIButton *)sender {
    NSLog(@"按钮被点击了");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
