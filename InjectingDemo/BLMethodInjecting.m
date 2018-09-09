//
// Created by NewPan on 2018/9/5.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import "BLMethodInjecting.h"
#import "JRSwizzle.h"
#import <pthread.h>
#import <objc/runtime.h>

typedef struct BLSpecialProtocol {
    __unsafe_unretained Protocol *protocol;
    Class containerClass;
    BOOL ready;
} BLSpecialProtocol;

static BLSpecialProtocol * restrict bl_specialProtocols = NULL;
static size_t bl_specialProtocolCount = 0;
static size_t bl_specialProtocolCapacity = 0;
static size_t bl_specialProtocolsReady = 0;
static pthread_mutex_t bl_specialProtocolsLock = PTHREAD_MUTEX_INITIALIZER;
static dispatch_semaphore_t bl_specialProtocolsSemaphore;

BOOL bl_loadSpecialProtocol(Protocol *protocol, Class containerClass) {
    @autoreleasepool {
        NSCParameterAssert(protocol != nil);
        if (pthread_mutex_lock(&bl_specialProtocolsLock) != 0) {
            fprintf(stderr, "ERROR: Could not synchronize on special protocol data\n");
            return NO;
        }

        if (bl_specialProtocolCount == SIZE_MAX) {
            pthread_mutex_unlock(&bl_specialProtocolsLock);
            return NO;
        }

        if (bl_specialProtocolCount >= bl_specialProtocolCapacity) {
            size_t newCapacity;
            if (bl_specialProtocolCapacity == 0)
                newCapacity = 1;
            else {
                newCapacity = bl_specialProtocolCapacity << 1;

                if (newCapacity < bl_specialProtocolCapacity) {
                    newCapacity = SIZE_MAX;

                    if (newCapacity <= bl_specialProtocolCapacity) {
                        pthread_mutex_unlock(&bl_specialProtocolsLock);
                        return NO;
                    }
                }
            }

            void * restrict ptr = realloc(bl_specialProtocols, sizeof(*bl_specialProtocols) * newCapacity);
            if (!ptr) {
                pthread_mutex_unlock(&bl_specialProtocolsLock);
                return NO;
            }

            bl_specialProtocols = ptr;
            bl_specialProtocolCapacity = newCapacity;
        }
        assert(bl_specialProtocolCount < bl_specialProtocolCapacity);

#ifndef __clang_analyzer__

        bl_specialProtocols[bl_specialProtocolCount] = (BLSpecialProtocol){
                .protocol = protocol,
                .containerClass = containerClass,
                .ready = NO,
        };
#endif

        ++bl_specialProtocolCount;
        pthread_mutex_unlock(&bl_specialProtocolsLock);
    }

    return YES;
}

static void bl_orderSpecialProtocols(void) {
    qsort_b(bl_specialProtocols, bl_specialProtocolCount, sizeof(BLSpecialProtocol), ^(const void *a, const void *b){
        if (a == b)
            return 0;

        const BLSpecialProtocol *protoA = a;
        const BLSpecialProtocol *protoB = b;

        int (^protocolInjectionPriority)(const BLSpecialProtocol *) = ^(const BLSpecialProtocol *specialProtocol){
            int runningTotal = 0;

            for (size_t i = 0;i < bl_specialProtocolCount;++i) {
                if (specialProtocol == bl_specialProtocols + i)
                    continue;

                if (protocol_conformsToProtocol(specialProtocol->protocol, bl_specialProtocols[i].protocol))
                    runningTotal++;
            }

            return runningTotal;
        };
        return protocolInjectionPriority(protoB) - protocolInjectionPriority(protoA);
    });
}

void bl_specialProtocolReadyForInjection(Protocol *protocol) {
    @autoreleasepool {
        NSCParameterAssert(protocol != nil);

        if (pthread_mutex_lock(&bl_specialProtocolsLock) != 0) {
            fprintf(stderr, "ERROR: Could not synchronize on special protocol data\n");
            return;
        }
        for (size_t i = 0;i < bl_specialProtocolCount;++i) {
            if (bl_specialProtocols[i].protocol == protocol) {
                if (!bl_specialProtocols[i].ready) {
                    bl_specialProtocols[i].ready = YES;
                    assert(bl_specialProtocolsReady < bl_specialProtocolCount);
                    if (++bl_specialProtocolsReady == bl_specialProtocolCount)
                        bl_orderSpecialProtocols();
                }

                break;
            }
        }

        pthread_mutex_unlock(&bl_specialProtocolsLock);
    }
}

static void bl_logInstanceAndClassMethod(Class cls) {
    unsigned imethodCount = 0;
    Method *imethodList = class_copyMethodList(cls, &imethodCount);
    NSLog(@"instance Method--------------------");
    for (unsigned methodIndex = 0;methodIndex < imethodCount;++methodIndex) {
        Method method = imethodList[methodIndex];
        SEL selector = method_getName(method);
        NSLog(@"%@", [NSString stringWithFormat:@"-[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(selector)]);
    }
    free(imethodList); imethodList = NULL;

    unsigned cmethodCount = 0;
    Method *cmethodList = class_copyMethodList(object_getClass(cls), &cmethodCount);

    NSLog(@"class Method--------------------");
    for (unsigned methodIndex = 0;methodIndex < cmethodCount;++methodIndex) {
        Method method = cmethodList[methodIndex];
        SEL selector = method_getName(method);
        NSLog(@"%@", [NSString stringWithFormat:@"+[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(selector)]);
    }

    free(cmethodList); cmethodList = NULL;
    NSLog(@"end----------------------------------------");
}

static void bl_injectConcreteProtocolInjectMethod(Class containerClass, Class pairClass) {
    unsigned imethodCount = 0;
    Method *imethodList = class_copyMethodList(containerClass, &imethodCount);
    for (unsigned methodIndex = 0;methodIndex < imethodCount;++methodIndex) {
        Method method = imethodList[methodIndex];
        SEL selector = method_getName(method);
        if (class_getInstanceMethod(pairClass, selector)) {
            continue;
        }
        IMP imp = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        bool success = class_addMethod(pairClass, selector, imp, types);
        assert(success);
    }
    free(imethodList); imethodList = NULL;
    (void)[containerClass class];

    unsigned cmethodCount = 0;
    Method *cmethodList = class_copyMethodList(object_getClass(containerClass), &cmethodCount);

    Class metaclass = object_getClass(pairClass);
    for (unsigned methodIndex = 0;methodIndex < cmethodCount;++methodIndex) {
        Method method = cmethodList[methodIndex];
        SEL selector = method_getName(method);

        if (selector == @selector(initialize)) {
            continue;
        }
        if (class_getInstanceMethod(metaclass, selector)) {
            continue;
        }

        IMP imp = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        bool success = class_addMethod(metaclass, selector, imp, types);
        assert(success);
    }

    free(cmethodList); cmethodList = NULL;
    (void)[containerClass class];
}

static NSArray * bl_injectMethod(id object, Class pairClass) {
    assert(object);
    assert(pairClass);
    if(!object || !pairClass) {
        return nil;
    }

    NSMutableArray *bl_matchSpecialProtocolsToClass = @[].mutableCopy;
    for (size_t i = 0;i < bl_specialProtocolCount;++i) {
        @autoreleasepool {
            Protocol *protocol = bl_specialProtocols[i].protocol;
            if (!class_conformsToProtocol([object class], protocol)) {
                continue;
            }
            [bl_matchSpecialProtocolsToClass addObject:[NSValue value:&bl_specialProtocols[i] withObjCType:@encode(struct BLSpecialProtocol)]];
        }
    }

    if(!bl_matchSpecialProtocolsToClass.count) {
        return nil;
    }

    struct BLSpecialProtocol protocol;
    for(NSValue *value in bl_matchSpecialProtocolsToClass) {
        [value getValue:&protocol];
        bl_injectConcreteProtocolInjectMethod(protocol.containerClass, [object class]);
        bl_injectConcreteProtocolInjectMethod(protocol.containerClass, pairClass);
    }
    return bl_matchSpecialProtocolsToClass.copy;
}

static id bl_retrieveForwardTargetForSelector(id object, bool isInstanceMethod) {
    assert(object);
    if(!object) {
        return nil;
    }

    @autoreleasepool {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            bl_specialProtocolsSemaphore = dispatch_semaphore_create(1);
        });

        dispatch_semaphore_wait(bl_specialProtocolsSemaphore, DISPATCH_TIME_FOREVER);

        // 新建当前类的子类来响应对应的方法.
        const char *pairClassName = [[NSStringFromClass([object class]) stringByReplacingOccurrencesOfString:@"_BLInjectingPairClass" withString:@""] stringByAppendingString:@"_BLInjectingPairClass"].UTF8String;
        Class pairClass = objc_getClass(pairClassName);
        if(!pairClass) {
            pairClass = objc_allocateClassPair([object class], pairClassName, 0);
            objc_registerClassPair(pairClass);
        }

        // 处理继承自有注入的父类.
        Class currentClass = [object class];
        NSArray *matchSpecialProtocolsToClass = nil;
        do {
            NSArray *protocols = bl_injectMethod(currentClass, pairClass);
            if(!matchSpecialProtocolsToClass) {
                matchSpecialProtocolsToClass = protocols;
            }
        }while((currentClass = class_getSuperclass(currentClass)));

        if(!matchSpecialProtocolsToClass.count) {
            dispatch_semaphore_signal(bl_specialProtocolsSemaphore);
            return nil;
        }

        id forwardTarget = pairClass;
        if(isInstanceMethod) {
            @try {
                forwardTarget = [pairClass new];
            }
            @catch(id exp) {
                forwardTarget = [pairClass alloc];
                NSLog(@"初始化注入 pairClass 实例对象时调用的 init 方法不是指定的初始化方法, 但是对方法注入没有影响, 错误信息: %@", exp);
            }
        }
        dispatch_semaphore_signal(bl_specialProtocolsSemaphore);
        return forwardTarget;
    }
}

BOOL bl_addConcreteProtocol(Protocol *protocol, Class containerClass) {
    return bl_loadSpecialProtocol(protocol, containerClass);
}

void bl_loadConcreteProtocol(Protocol *protocol) {
    bl_specialProtocolReadyForInjection(protocol);
}

@interface NSObject(BLInjecting)

@end

@implementation NSObject(BLInjecting)

+ (void)load {
    NSError *iError;
    NSError *cError;
    [self jr_swizzleMethod:@selector(forwardingTargetForSelector:)
                withMethod:@selector(blinjecting_forwardingTargetForSelector:)
                     error:&iError];
    [self jr_swizzleClassMethod:@selector(forwardingTargetForSelector:)
                withClassMethod:@selector(blinjecting_forwardingTargetForSelector:)
                          error:&cError];
    NSParameterAssert(!iError);
    NSParameterAssert(!cError);
}

+ (id)blinjecting_forwardingTargetForSelector:(SEL)aSelector {
    id target = bl_retrieveForwardTargetForSelector(self, NO);
    if(target) {
        return target;
    }
    return [self blinjecting_forwardingTargetForSelector:aSelector];
}

- (id)blinjecting_forwardingTargetForSelector:(SEL)aSelector {
    id target = bl_retrieveForwardTargetForSelector(self, YES);
    if(target) {
        return target;
    }
    return [self blinjecting_forwardingTargetForSelector:aSelector];
}

@end