//
// Created by NewPan on 2018/9/8.
// Copyright (c) 2018 ___FULLUSERNAME___. All rights reserved.
//

#import "Animal.h"

@interface Dog : Animal<TopProtocol>

@property(nonatomic, copy, readonly) NSString *name;

- (instancetype)initWithName:(NSString *)name;

@end