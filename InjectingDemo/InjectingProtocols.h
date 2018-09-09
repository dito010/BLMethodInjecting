//
// Created by NewPan on 2018/9/8.
// Copyright (c) 2018 ___FULLUSERNAME___. All rights reserved.
//

#import "BLMethodInjecting.h"

@protocol ObjectProtocol<NSObject>

@bl_concrete
+ (void)sayHello;

@bl_concrete
- (int)age;

@property(nonatomic) id userSession;

@end

@protocol UnderlyingProtocol<ObjectProtocol>

@bl_concrete
+ (void)eat;

@bl_concrete
- (int)weight;

@end

@protocol TopProtocol<NSObject>

@bl_concrete
+ (void)sleep;

@bl_concrete
- (int)height;

@end
