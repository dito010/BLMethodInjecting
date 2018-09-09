//
// Created by NewPan on 2018/9/8.
// Copyright (c) 2018 ___FULLUSERNAME___. All rights reserved.
//

#import "InjectingProtocols.h"

@bl_concreteprotocol(ObjectProtocol)

+ (void)sayHello {
    NSLog(@"Hello");
}

- (int)age {
    return 18;
}

static id _userSession;
- (void)setUserSession:(id)userSession {
    _userSession = userSession;
}

- (id)userSession {
    return _userSession;
}

@end

@bl_concreteprotocol(UnderlyingProtocol)

+ (void)eat {
    NSLog(@"Eat breakfast");
}

- (int)weight {
    return 108;
}

@end


@bl_concreteprotocol(TopProtocol)

+ (void)sleep {
    NSLog(@"Sleeping");
}

- (int)height {
    return 187;
}

@end