//
//  ViewController.m
//  InjectingDemo
//
//  Created by NewPan on 2018/9/7.
//  Copyright © 2018 NewPan. All rights reserved.
//

#import "ViewController.h"
#import "Dog.h"

@interface ViewController ()<UnderlyingProtocol>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.userSession = @"userSession";

    Dog *d = [[Dog alloc] initWithName:@"贝贝"];

    [Dog sayHello];
    NSLog(@"%d", [d age]);

    [Dog eat];
    NSLog(@"%d", [d weight]);

    [Dog sleep];
    NSLog(@"%d", [d height]);

    NSLog(@"%@", [d userSession]);
}

@end