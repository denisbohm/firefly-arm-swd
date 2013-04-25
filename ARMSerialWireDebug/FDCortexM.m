//
//  FDCortexM.m
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDCortexM.h"
#import "FDSerialWireDebug.h"

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

typedef struct {
    UInt32 location;
    UInt32 length;
} AddressRange;

@interface FDCortexM ()

@property AddressRange programRange;
@property AddressRange stackRange;
@property AddressRange heapRange;

@end

@implementation FDCortexM

- (void)run:(UInt32)pc
{
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_R0 value:_heapRange.location];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_SP value:_stackRange.location + _stackRange.length];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_PC value:pc];
    [_serialWireDebug run];
}

@end