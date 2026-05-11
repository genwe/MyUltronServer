//
//  MUSViewController.m
//  MyUltronServer
//
//  Created by genwe on 05/06/2026.
//  Copyright (c) 2026 genwe. All rights reserved.
//

#import "MUSViewController.h"

@interface MUSViewController ()

@end

@implementation MUSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"key1"];
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
