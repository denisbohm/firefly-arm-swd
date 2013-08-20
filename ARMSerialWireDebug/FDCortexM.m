//
//  FDCortexM.m
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDCortexM.h"
#import "FDLogger.h"
#import "FDSerialWireDebug.h"

@implementation FDAddressRange
@end

@interface FDCortexM ()

@end

@implementation FDCortexM

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
        _programRange = [[FDAddressRange alloc] init];
        _stackRange = [[FDAddressRange alloc] init];
        _heapRange = [[FDAddressRange alloc] init];
    }
    return self;
}

+ (NSString *)debugPortIDCodeDescription:(uint32_t)debugPortIDCode
{
    return [NSString stringWithFormat:@"TAP ID %08x", debugPortIDCode];
    /*
     unsigned version = (debugPortIDCode >> 28) & 0xf;
     unsigned partNumber = (debugPortIDCode >> 12) & 0xff;
     unsigned manufacturer = debugPortIDCode & 0x7f;
     unsigned marker = debugPortIDCode & 0x1;
     if (marker != 1) {
     FDLog(@"invalid debug port identification code %08x: marker not set", debugPortIDCode);
     }
     if (manufacturer == 0x477) {
     FDLog(@"TAP ID: ARM is the manufacturer");
     }
     FDLog(@"TAP ID: version %u, part number %u, manufacturer %03x", version, partNumber, manufacturer);
     unsigned coreAndCapability = (partNumber >> 8) & 0xf;
     NSString *capabilityName = nil;
     switch (coreAndCapability) {
     case 0x0: capabilityName = @"ARM Processor pre E extension - hard macrocell"; break;
     case 0x1: capabilityName = @"ARM Processor pre E extension - soft macrocell"; break;
     case 0x2: capabilityName = @"Reserved"; break;
     case 0x3: capabilityName = @"Reserved"; break;
     case 0x4: capabilityName = @"ARM processor with E extension - hard macrocell"; break;
     case 0x5: capabilityName = @"ARM processor with E extension - soft macrocell"; break;
     case 0x6: capabilityName = @"ARM Processor with J extension - hard macrocell"; break;
     case 0x7: capabilityName = @"ARM Processor with J extension - soft macrocell"; break;
     case 0x8: capabilityName = @"Reserved"; break;
     case 0x9: capabilityName = @"Not a recognized executable ARM device"; break;
     case 0xa: capabilityName = @"Reserved"; break;
     case 0xb: capabilityName = @"ARM Embedded Trace Buffer"; break;
     case 0xc: capabilityName = @"Reserved"; break;
     case 0xd: capabilityName = @"Reserved"; break;
     case 0xe: capabilityName = @"Reserved"; break;
     case 0xf: capabilityName = @"Test chip boundary scan ID"; break;
     }
     FDLog(@"TAP ID: capability %@", capabilityName);
     unsigned processorCore = partNumber >> 11;
     unsigned family = partNumber >> 8;
     unsigned deviceNumber = partNumber & 0xff;
     FDLog(@"TAP ID: %@ processor core, family ARM%u, device number %u", processorCore ? @"non-ARM" : @"ARM", family, deviceNumber);
     */
}

+ (NSString *)cpuIDDescription:(uint32_t)cpuID
{
    //    FDLog(@"CPU ID = %08x", cpuID);
    unsigned implementer = (cpuID >> 24) & 0xff;
    //    unsigned variant = (cpuID >> 20) & 0xf;
    //    unsigned constant = (cpuID >> 16) & 0xf;
    unsigned partno = (cpuID >> 4) & 0xfff;
    //    unsigned revision = cpuID & 0xf;
    //    FDLog(@"CPU ID: implementer %02x, variant %u, constant %x, partno %03x, revision %u", implementer, variant, constant, partno, revision);
    NSString *implementerName = @"unknown";
    switch (implementer) {
        case 0x41: implementerName = @"ARM"; break;
    }
    NSString *partnoName = @"";
    switch (partno) {
        case 0xC20: partnoName = @"Cortex-M0"; break;
        case 0xC60: partnoName = @"Cortex-M0+"; break;
        case 0xC21: partnoName = @"Cortex-M1"; break;
        case 0xC23: partnoName = @"Cortex-M3"; break;
        case 0xC24: partnoName = @"Cortex-M4"; break;
    }
    //    FDLog(@"CPU ID: %@ %@ r%dp%d", implementerName, partnoName, variant, revision);
    if ((cpuID & 0xfffffff0) == 0x412fc230) {
        uint32_t n = cpuID & 0x0000000f;
        return [NSString stringWithFormat:@"ARM Cortex-M3 r2p%d", n];
    }
    if ((cpuID & 0xfffffff0) == 0x410cc200) {
        uint32_t n = cpuID & 0x0000000f;
        return [NSString stringWithFormat:@"ARM Cortex-M0 r0p%d", n];
    }
    return [NSString stringWithFormat:@"CPUID = %08x", cpuID];
}

- (void)identify
{
    [_serialWireDebug resetDebugPort];
    uint32_t debugPortIDCode = [_serialWireDebug readDebugPortIDCode];
    NSLog(@"%@", [FDCortexM debugPortIDCodeDescription:debugPortIDCode]);
    [_serialWireDebug initializeDebugPort];
    
    if ([_serialWireDebug isAuthenticationAccessPortActive]) {
        FDLog(@"Authentication AP is active - erasing device to gain access.");
        [_serialWireDebug authenticationAccessPortErase];
        [_serialWireDebug authenticationAccessPortReset];
        [NSThread sleepForTimeInterval:0.1];
    }
    
    [_serialWireDebug initializeAccessPort];
    uint32_t cpuID = [_serialWireDebug readCPUID];
    FDLog(@"%@", [FDCortexM cpuIDDescription:cpuID]);
}

- (uint32_t)run:(UInt32)pc timeout:(NSTimeInterval)timeout
{
    return [self run:pc r0:0 r1:0 r2:0 r3:0 timeout:timeout];
}

- (uint32_t)run:(UInt32)pc r0:(uint32_t)r0 timeout:(NSTimeInterval)timeout
{
    return [self run:pc r0:r0 r1:0 r2:0 r3:0 timeout:timeout];
}

- (uint32_t)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 timeout:(NSTimeInterval)timeout
{
    return [self run:pc r0:r0 r1:r1 r2:0 r3:0 timeout:timeout];
}

- (uint32_t)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 timeout:(NSTimeInterval)timeout
{
    return [self run:pc r0:r0 r1:r1 r2:r2 r3:0 timeout:timeout];
}

- (uint32_t)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3 timeout:(NSTimeInterval)timeout
{
    [_serialWireDebug halt];
    // Can only use hardware breakpoints if code is in FLASH.
    // Instead we set the link register to a halt function, which then gets called on return. -denis
    /*
    [_serialWireDebug disableAllBreakpoints];
    [_serialWireDebug setBreakpoint:0 address:_breakLocation];
    [_serialWireDebug enableBreakpoints:YES];
     */
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_R0 value:r0];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_R1 value:r1];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_R2 value:r2];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_R3 value:r3];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_SP value:_stackRange.location + _stackRange.length];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_PC value:pc];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_LR value:_breakLocation | 0x00000001];
    [_serialWireDebug run];
    [_serialWireDebug waitForHalt:timeout];
    return [_serialWireDebug readRegister:CORTEX_M_REGISTER_R0];
}

@end
