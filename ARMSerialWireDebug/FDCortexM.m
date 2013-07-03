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

@interface FDCortexM ()

@end

@implementation FDCortexM

- (void)identify
{
    [_serialWireDebug resetDebugAccessPort];
    uint32_t debugPortIDCode = [_serialWireDebug readDebugPortIDCode];
    FDLog(@"TAP ID %08x", debugPortIDCode);
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
    
    [_serialWireDebug initializeDebugAccessPort];
    uint32_t cpuID = [_serialWireDebug readCPUID];
    FDLog(@"CPU ID = %08x", cpuID);
    unsigned implementer = (cpuID >> 24) & 0xff;
    unsigned variant = (cpuID >> 20) & 0xf;
    unsigned constant = (cpuID >> 16) & 0xf;
    unsigned partno = (cpuID >> 4) & 0xfff;
    unsigned revision = cpuID & 0xf;
    FDLog(@"CPU ID: implementer %02x, variant %u, constant %x, partno %03x, revision %u", implementer, variant, constant, partno, revision);
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
    FDLog(@"CPU ID: %@ %@ r%dp%d", implementerName, partnoName, variant, revision);
    if ((cpuID & 0xfffffff0) == 0x412fc230) {
        uint32_t n = cpuID & 0x0000000f;
        FDLog(@"ARM Cortex-M3 r2p%d", n);
    } else
    if ((cpuID & 0xfffffff0) == 0x410cc200) {
        uint32_t n = cpuID & 0x0000000f;
        FDLog(@"ARM Cortex-M0 r0p%d", n);
    } else {
        FDLog(@"CPUID = %08x", cpuID);
    }
}

- (void)run:(UInt32)pc timeout:(NSTimeInterval)timeout
{
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_R0 value:_heapRange.location];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_SP value:_stackRange.location + _stackRange.length];
    [_serialWireDebug writeRegister:CORTEX_M_REGISTER_PC value:pc];
    [_serialWireDebug run];
    [_serialWireDebug waitForHalt:timeout];
}

@end
