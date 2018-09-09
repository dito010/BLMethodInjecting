//
// Created by NewPan on 2018/9/5.
// Copyright (c) 2018 NewPan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define bl_metamacro_stringify_(VALUE) # VALUE

#define bl_metamacro_stringify(VALUE) \
        bl_metamacro_stringify_(VALUE)

#define bl_concrete \
    optional \

#define bl_concreteprotocol(NAME) \
    interface NAME ## _BLProtocolMethodContainer : NSObject < NAME > {} \
    @end \
    @implementation NAME ## _BLProtocolMethodContainer \
    + (void)load { \
        if (!bl_addConcreteProtocol(objc_getProtocol(bl_metamacro_stringify(NAME)), self)) \
            fprintf(stderr, "ERROR: Could not load concrete protocol %s\n", bl_metamacro_stringify(NAME)); \
    } \
    __attribute__((constructor)) \
    static void bl_ ## NAME ## _inject (void) { \
        bl_loadConcreteProtocol(objc_getProtocol(bl_metamacro_stringify(NAME))); \
    }

BOOL bl_addConcreteProtocol (Protocol *protocol, Class methodContainer);
void bl_loadConcreteProtocol (Protocol *protocol);