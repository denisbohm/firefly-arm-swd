//
//  FDSerialWireDebug.h
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDSerialEngine;

@interface FDSerialWireDebug : NSObject

@property FDSerialEngine *serialEngine;

- (void)initialize;

- (void)getGpios;

- (void)setGpioIndicator:(bool)value;
- (void)setGpioReset:(bool)value;

- (void)resetDebugAccessPort;
- (UInt32)readDebugPortIDCode;
- (void)initializeDebugAccessPort;
- (UInt32)readCPUID;

- (void)checkDebugPortStatus;

- (UInt32)readMemory:(UInt32)address;
- (void)writeMemory:(UInt32)address value:(UInt32)value;

- (UInt32)readRegister:(UInt16)registerID;
- (void)writeRegister:(UInt16)registerID value:(UInt32)value;

- (void)halt;
- (void)step;
- (void)run;

@end
