//
//  FDCortexM.m
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDCortexM.h"
#import "FDSerialWireDebug.h"

@interface FDCortexM ()

@end

@implementation FDCortexM

- (void)run:(UInt32)pc timeout:(NSTimeInterval)timeout
{
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_R0 value:_heapRange.location];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_SP value:_stackRange.location + _stackRange.length];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_PC value:pc];
    [_serialWireDebug run];
    [_serialWireDebug waitForHalt:timeout];
}

@end
