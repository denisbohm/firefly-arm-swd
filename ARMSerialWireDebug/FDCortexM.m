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
    /*
    unsigned revision = (debugPortIDCode >> 28) & 0xf;
    unsigned partNumber = (debugPortIDCode >> 20) & 0xff;
    BOOL min = (debugPortIDCode >> 16) & 0x1 ? YES : NO;
    unsigned version = (debugPortIDCode >> 12) & 0xf;
    unsigned designer = (debugPortIDCode >> 1) & 0x7ff;
    unsigned marker = debugPortIDCode & 0x1;
    if (marker != 1) {
        NSLog(@"invalid debug port identification code %08x: marker not set", debugPortIDCode);
    }
    if (designer == 0x23B) {
        NSLog(@"TAP ID: ARM is the manufacturer");
    }
    NSLog(@"TAP ID: revision %u, part number %02x, min %@, version %u, designer %03x", revision, partNumber, min ? @"YES" : @"NO", version, designer);
     */
    
    /*
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
    NSLog(@"TAP ID: capability %@", capabilityName);
    unsigned processorCore = partNumber >> 11;
    unsigned family = partNumber >> 8;
    unsigned deviceNumber = partNumber & 0xff;
    NSLog(@"TAP ID: %@ processor core, family ARM%u, device number %u", processorCore ? @"non-ARM" : @"ARM", family, deviceNumber);
     */
    
    return [NSString stringWithFormat:@"IDCODE %08x", debugPortIDCode];
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
    if ((cpuID & 0xfffffff0) == 0x410fc240) {
        uint32_t n = cpuID & 0x0000000f;
        return [NSString stringWithFormat:@"ARM Cortex-M4 r2p%d", n];
    }
    if ((cpuID & 0xfffffff0) == 0x412fc230) {
        uint32_t n = cpuID & 0x0000000f;
        return [NSString stringWithFormat:@"ARM Cortex-M3 r2p%d", n];
    }
    if ((cpuID & 0xfffffff0) == 0x410cc200) {
        uint32_t n = cpuID & 0x0000000f;
        return [NSString stringWithFormat:@"ARM Cortex-M0 r0p%d", n];
    }
    if ((cpuID & 0xfffffff0) == 0x410cc600) {
        uint32_t n = cpuID & 0x0000000f;
        return [NSString stringWithFormat:@"ARM Cortex-M0+ r0p%d", n];
    }
    return [NSString stringWithFormat:@"CPUID = %08x", cpuID];
}

- (void)identify
{
    [_serialWireDebug resetDebugPort];
    uint32_t debugPortIDCode = [_serialWireDebug readDebugPortIDCode];
    NSLog(@"%@", [FDCortexM debugPortIDCodeDescription:debugPortIDCode]);
    // if debug architecture version is 2 then read target id...
    // uint32_t targetId = [_serialWireDebug readTargetID];
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

- (void)logDebugInfo
{
    uint32_t dhcsr = [_serialWireDebug readMemory:0xE000EDF0];
    uint32_t demcr = [_serialWireDebug readMemory:0xE000EDFC];
    uint32_t pc = [_serialWireDebug readRegister:CORTEX_M_REGISTER_PC];
    uint32_t lr = [_serialWireDebug readRegister:CORTEX_M_REGISTER_LR];
    NSLog(@"run timeout: dhcsr=0x%08x demcr=0x%08x pc=0x%08x lr=0x%08x", dhcsr, demcr, pc, lr);
}

- (void)start:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3
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
}

- (uint32_t)waitForHalt:(NSTimeInterval)timeout
{
    @try {
        [_serialWireDebug waitForHalt:timeout];
    } @catch (NSException *e) {
        @try {
            [self logDebugInfo];
            uint32_t current_pc = [_serialWireDebug readRegister:CORTEX_M_REGISTER_PC];
            if (current_pc == (_breakLocation | 0x00000001)) {
                uint16_t instruction = [_serialWireDebug readMemoryUInt16:_breakLocation];
                NSLog(@"halted, but halt bit not set (0x%08x = 0x%04x)", _breakLocation, instruction);
                return [_serialWireDebug readRegister:CORTEX_M_REGISTER_R0];
            }
        } @catch (NSException *) {
        }
        @throw;
    }
    return [_serialWireDebug readRegister:CORTEX_M_REGISTER_R0];
}

- (uint32_t)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3 timeout:(NSTimeInterval)timeout
{
    [self start:pc r0:r0 r1:r1 r2:r2 r3:r3];
    return [self waitForHalt:timeout];
}

@end
