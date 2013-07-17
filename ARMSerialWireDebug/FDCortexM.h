//
//  FDCortexM.h
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#define CORTEX_M_REGISTER_R0    0
#define CORTEX_M_REGISTER_R1    1
#define CORTEX_M_REGISTER_R2    2
#define CORTEX_M_REGISTER_R3    3
#define CORTEX_M_REGISTER_R4    4
#define CORTEX_M_REGISTER_R5    5
#define CORTEX_M_REGISTER_R6    6
#define CORTEX_M_REGISTER_R7    7
#define CORTEX_M_REGISTER_R8    8
#define CORTEX_M_REGISTER_R9    9
#define CORTEX_M_REGISTER_R10  10
#define CORTEX_M_REGISTER_R11  11
#define CORTEX_M_REGISTER_R12  12
#define CORTEX_M_REGISTER_IP   12
#define CORTEX_M_REGISTER_R13  13
#define CORTEX_M_REGISTER_SP   13
#define CORTEX_M_REGISTER_R14  14
#define CORTEX_M_REGISTER_LR   14
#define CORTEX_M_REGISTER_R15  15
#define CORTEX_M_REGISTER_PC   15
#define CORTEX_M_REGISTER_XPSR 16
#define CORTEX_M_REGISTER_MSP  17
#define CORTEX_M_REGISTER_PSP  18

@interface FDAddressRange : NSObject
@property UInt32 location;
@property UInt32 length;
@end

@class FDLogger;
@class FDSerialWireDebug;

@interface FDCortexM : NSObject

@property FDSerialWireDebug *serialWireDebug;
@property FDLogger *logger;

@property FDAddressRange *programRange;
@property FDAddressRange *stackRange;
@property FDAddressRange *heapRange;
@property uint32_t breakLocation;

- (void)identify;

- (uint32_t)run:(UInt32)pc timeout:(NSTimeInterval)timeout;
- (uint32_t)run:(UInt32)pc r0:(uint32_t)r0 timeout:(NSTimeInterval)timeout;
- (uint32_t)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 timeout:(NSTimeInterval)timeout;

@end
