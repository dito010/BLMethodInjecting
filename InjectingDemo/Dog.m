//
// Created by NewPan on 2018/9/8.
// Copyright (c) 2018 ___FULLUSERNAME___. All rights reserved.
//

#import "Dog.h"


@implementation Dog

- (instancetype)init {
    NSAssert(NO, @"请使用指定的初始化方法");
    return [self initWithName:nil];
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if(self) {
        _name = name;
    }
    return self;
}

@end