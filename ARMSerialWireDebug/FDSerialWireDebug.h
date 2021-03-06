//
//  FDSerialWireDebug.h
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDLogger;
@class FDSerialEngine;

@interface FDSerialWireDebug : NSObject

@property FDSerialEngine *serialEngine;
@property FDLogger *logger;

@property UInt16 clockDivisor;

@property BOOL maskInterrupts;

@property BOOL minimalDebugPort;

- (void)initialize;

- (BOOL)getGpioDetect;

- (void)setGpioIndicator:(BOOL)value;
- (void)setGpioReset:(BOOL)value;

- (void)detachDebugPort;
- (void)resetDebugPort;
- (UInt32)readDebugPortIDCode;
- (UInt32)readTargetID;
- (void)initializeDebugPort;

- (BOOL)isAuthenticationAccessPortActive;
- (void)authenticationAccessPortErase;
- (void)authenticationAccessPortReset;

- (uint32_t)readAccessPortID;
- (void)initializeAccessPort;

- (UInt32)readCPUID;

- (void)checkDebugPortStatus;

- (UInt32)readMemory:(UInt32)address;
- (void)writeMemory:(UInt32)address value:(UInt32)value;

- (void)writeMemory:(UInt32)address data:(NSData *)data;
- (NSData *)readMemory:(UInt32)address length:(UInt32)length;

- (UInt8)readMemoryUInt8:(UInt32)address;
- (UInt16)readMemoryUInt16:(UInt32)address;

- (void)setVectorTable:(uint32_t)address;

- (void)massErase;
- (void)erase:(UInt32)address;
- (void)flash:(UInt32)address data:(NSData *)data;

- (void)reset;

- (UInt32)readRegister:(UInt16)registerID;
- (void)writeRegister:(UInt16)registerID value:(UInt32)value;

- (void)halt;
- (void)step;
- (void)run;

- (BOOL)isHalted;
- (void)waitForHalt:(NSTimeInterval)timeout;

- (uint32_t)breakpointCount;
- (void)enableBreakpoints:(BOOL)enable;
- (BOOL)getBreakpoint:(uint32_t)n address:(uint32_t *)address;
- (void)setBreakpoint:(uint32_t)n address:(uint32_t)address;
- (void)disableBreakpoint:(uint32_t)n;
- (void)disableAllBreakpoints;

@end
