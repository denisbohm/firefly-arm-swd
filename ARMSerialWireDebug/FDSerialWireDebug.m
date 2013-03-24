//
//  FDSerialWireDebug.m
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDLogger.h"
#import "FDSerialEngine.h"
#import "FDSerialWireDebug.h"

#define BIT(n) (1 << (n))

#define SWD_DP_IDCODE 0x00
#define SWD_DP_ABORT  0x00
#define SWD_DP_CTRL   0x04
#define SWD_DP_STAT   0x04
#define SWD_DP_SELECT 0x08
#define SWD_DP_RDBUFF 0x0c

#define SWD_DP_ABORT_ORUNERRCLR BIT(4)
#define SWD_DP_ABORT_WDERRCLR BIT(3)
#define SWD_DP_ABORT_STKERRCLR BIT(2)
#define SWD_DP_ABORT_STKCMPCLR BIT(1)
#define SWD_DP_ABORT_DAPABORT BIT(0)

#define SWD_DP_CTRL_CSYSPWRUPACK BIT(31)
#define SWD_DP_CTRL_CSYSPWRUPREQ BIT(30)
#define SWD_DP_CTRL_CDBGPWRUPACK BIT(29)
#define SWD_DP_CTRL_CDBGPWRUPREQ BIT(28)
#define SWD_DP_CTRL_CDBGRSTACK BIT(27)
#define SWD_DP_CTRL_CDBGRSTREQ BIT(26)
#define SWD_DP_STAT_WDATAERR BIT(7)
#define SWD_DP_STAT_READOK BIT(6)
#define SWD_DP_STAT_STICKYERR BIT(5)
#define SWD_DP_STAT_STICKYCMP BIT(4)
#define SWD_DP_STAT_TRNMODE BIT(3) | BIT(2)
#define SWD_DP_STAT_STICKYORUN BIT(1)
#define SWD_DP_STAT_ORUNDETECT BIT(0)

#define SWD_AP_CSW 0x00
#define SWD_AP_TAR 0x04
#define SWD_AP_SBZ 0x08
#define SWD_AP_DRW 0x0c
#define SWD_AP_BD0 0x10
#define SWD_AP_BD1 0x14
#define SWD_AP_BD2 0x18
#define SWD_AP_BD3 0x1c
#define SWD_AP_DBGDRAR 0xf8
#define SWD_AP_IDR 0xfc

#define SWD_AP_CSW_DBGSWENABLE BIT(31)
#define SWD_AP_CSW_MASTER_DEBUG BIT(29)
#define SWD_AP_CSW_HPROT BIT(25)
#define SWD_AP_CSW_SPIDEN BIT(23)
#define SWD_AP_CSW_TRIN_PROG BIT(7)
#define SWD_AP_CSW_DEVICE_EN BIT(6)
#define SWD_AP_CSW_INCREMENT_PACKED BIT(5)
#define SWD_AP_CSW_INCREMENT_SINGLE BIT(4)
#define SWD_AP_CSW_32BIT BIT(1)
#define SWD_AP_CSW_16BIT BIT(0)

#define SWD_MEMORY_CPUID 0xE000ED00
#define SWD_MEMORY_DFSR  0xE000ED30
#define SWD_MEMORY_DHCSR 0xE000EDF0
#define SWD_MEMORY_DCRSR 0xE000EDF4
#define SWD_MEMORY_DCRDR 0xE000EDF8
#define SWD_MEMORY_DEMCR 0xE000EDFC

#define SWD_DHCSR_DBGKEY 0xA05F0000
#define SWD_DHCSR_STAT_RESET_ST BIT(25)
#define SWD_DHCSR_STAT_RETIRE_ST BIT(24)
#define SWD_DHCSR_STAT_LOCKUP BIT(19)
#define SWD_DHCSR_STAT_SLEEP BIT(18)
#define SWD_DHCSR_STAT_HALT BIT(17)
#define SWD_DHCSR_STAT_REGRDY BIT(16)
#define SWD_DHCSR_CTRL_SNAPSTALL BIT(5)
#define SWD_DHCSR_CTRL_MASKINTS BIT(3)
#define SWD_DHCSR_CTRL_STEP BIT(2)
#define SWD_DHCSR_CTRL_HALT BIT(1)
#define SWD_DHCSR_CTRL_DEBUGEN BIT(0)

@interface FDSerialWireDebug ()

@property UInt16 gpioInputs;
@property UInt16 gpioOutputs;
@property UInt16 gpioDirections;

@property NSUInteger gpioWriteBit;
@property NSUInteger gpioNotResetBit;
@property NSUInteger gpioIndicatorBit;

@property NSUInteger ackWaitRetryCount;
@property NSUInteger debugPortStatusRetryCount;
@property NSUInteger registerRetryCount;

@property bool overrunDetectionEnabled;

@end

@implementation FDSerialWireDebug

- (id)init
{
    if (self = [super init]) {
        _gpioDirections = 0b0000111100011011;
        _gpioOutputs = 0b0000001000000000;
        _gpioWriteBit = 3;
        _gpioNotResetBit = 9;
        _gpioIndicatorBit = 11;
        
        _ackWaitRetryCount = 3;
        _debugPortStatusRetryCount = 3;
        _registerRetryCount = 3;
    }
    return self;
}

- (void)initialize
{
    [_serialEngine setLoopback:false];
    [_serialEngine setClockDivisor:5];
    [_serialEngine write];
    
    [_serialEngine setLatencyTimer:2];
    [_serialEngine setMPSEEBitMode];
    [_serialEngine reset];
    
    _gpioOutputs = 0x0000;
    _gpioDirections = 0x0000;
    [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    [_serialEngine write];
}

- (void)getGpios
{
    [_serialEngine getLowByte];
    [_serialEngine getHighByte];
    [_serialEngine sendImmediate];
    [_serialEngine write];
    NSData *data = [_serialEngine read:2];
    UInt8 *bytes = (UInt8 *)data.bytes;
    _gpioOutputs = (bytes[1] << 8) | bytes[0];
}

- (void)setGpioBit:(NSUInteger)bit value:(bool)value
{
    UInt16 mask = 1 << bit;
    UInt16 outputs = _gpioOutputs;
    if (value) {
        outputs |= mask;
    } else {
        outputs &= ~mask;
    }
    if (outputs == _gpioOutputs) {
        return;
    }
    if (mask & 0x00ff) {
        [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    } else {
        [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    }
}

- (void)setGpioIndicator:(bool)value
{
    [self setGpioBit:_gpioIndicatorBit value:value];
}

- (void)setGpioReset:(bool)value
{
    [self setGpioBit:_gpioNotResetBit value:!value];
}

- (void)shiftOutTurnToWrite
{
    [self setGpioBit:_gpioWriteBit value:true];
}

- (void)shiftOutTurnToRead
{
    [self setGpioBit:_gpioWriteBit value:false];
}

- (void)resetDebugAccessPort
{
    [self shiftOutTurnToWrite];
    UInt8 bytes[] = {
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0x9e,
        0xe7,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0x00,
    };
    [_serialEngine shiftOutDataLSBFirstNegativeEdge:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (UInt8)getParityUInt8:(UInt8)v {
    return (0x6996 >> ((v ^ (v >> 4)) & 0xf)) & 1;
}

- (UInt8)getParityUInt32:(UInt32)v {
    v ^= v >> 16;
    v ^= v >> 8;
    return [self getParityUInt8:v];
}

typedef enum {
    SWDDebugPort,
    SWDAccessPort,
} SWDPort;

typedef enum {
    SWDWriteDirection,
    SWDReadDirection,
} SWDDirection;

- (UInt8)encodeRequestPort:(SWDPort)port direction:(SWDDirection)direction address:(UInt8)address
{
    UInt8 request = 0b10000001;
    if (port == SWDAccessPort) {
        request |= 0b00000010;
    }
    if (port == SWDReadDirection) {
        request |= 0b00000100;
    }
    request |= (address << 1) & 0b00011000;
    if ([self getParityUInt8:request]) {
        request |= 0b00100000;
    }
    return request;
}

typedef enum {
    SWDOKAck = 0b001,
    SWDWaitAck = 0b010,
    SWDFaultAck = 0b100,
} SWDAck;

- (void)shiftInTurnAndAck
{
    [_serialEngine shiftInBitsLSBFirstPositiveEdge:4];
}

- (SWDAck)getTurnAndAck:(NSData *)data
{
    return ((UInt8 *)data.bytes)[0] >> 5;
}

- (SWDAck)request:(UInt8)request
{
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:request bitCount:8];
    [self shiftOutTurnToRead];
    [self shiftInTurnAndAck];
    [_serialEngine sendImmediate];
    NSData *data = [_serialEngine read:1];
    return [self getTurnAndAck:data];
}

- (UInt32)readUInt32
{
    [_serialEngine shiftInDataLSBFirstPositiveEdge:4];
    [_serialEngine shiftInBitsLSBFirstPositiveEdge:1]; // parity
    [_serialEngine sendImmediate];
    NSData *data = [_serialEngine read:5];
    UInt8 *bytes = (UInt8 *)data.bytes;
    UInt32 value = (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
    bool parity = bytes[4] >> 7;
    if (parity != [self getParityUInt32:value]) {
        @throw [NSException exceptionWithName:@"read error" reason:@"parity mismatch" userInfo:nil];
    }
    return value;
}

- (void)writeUInt32:(UInt32)value
{
    UInt8 bytes[] = {value, value >> 8, value >> 16, value >> 24, [self getParityUInt32:value]};
    [_serialEngine shiftOutDataLSBFirstNegativeEdge:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (UInt32)readPort:(SWDPort)port registerOffset:(UInt8)registerOffset
{
    UInt8 request = [self encodeRequestPort:port direction:SWDReadDirection address:registerOffset];
    for (NSUInteger retry = 0; retry < _ackWaitRetryCount; ++retry) {
        SWDAck ack = [self request:request];
        UInt32 value;
        if (_overrunDetectionEnabled) {
            value = [self readUInt32];
            [self shiftOutTurnToWrite];
        }
        if (ack == SWDOKAck) {
            if (!_overrunDetectionEnabled) {
                value = [self readUInt32];
                [self shiftOutTurnToWrite];
            }
            return value;
        }
        if (!_overrunDetectionEnabled) {
            [self shiftOutTurnToWrite];
        }
        if (ack != SWDWaitAck) {
            @throw [NSException exceptionWithName:@"read port error" reason:@"unexpected ack" userInfo:nil];
        }
    }
    @throw [NSException exceptionWithName:@"read port error" reason:@"too many retries" userInfo:nil];
}

- (void)writePort:(SWDPort)port registerOffset:(UInt8)registerOffset value:(UInt32)value
{
    UInt8 request = [self encodeRequestPort:port direction:SWDWriteDirection address:registerOffset];
    for (NSUInteger retry = 0; retry < _ackWaitRetryCount; ++retry) {
        SWDAck ack = [self request:request];
        [self shiftOutTurnToWrite];
        if (_overrunDetectionEnabled) {
            [self writeUInt32:value];
        }
        if (ack == SWDOKAck) {
            if (!_overrunDetectionEnabled) {
                [self writeUInt32:value];
            }
            return;
        }
        if (ack != SWDWaitAck) {
            @throw [NSException exceptionWithName:@"write port error" reason:@"unexpected ack" userInfo:nil];
        }
    }
    @throw [NSException exceptionWithName:@"write port error" reason:@"too many retries" userInfo:nil];
}

- (UInt32)readDebugPort:(UInt8)registerOffset
{
    return [self readPort:SWDDebugPort registerOffset:registerOffset];
}

- (void)writeDebugPort:(UInt8)registerOffset value:(UInt32)value
{
    [self writePort:SWDDebugPort registerOffset:registerOffset value:value];
}

- (UInt32)readDebugPortIDCode
{
    return [self readDebugPort:SWD_DP_IDCODE];
}

- (void)waitForDebugPortStatus:(UInt32)mask
{
    for (NSUInteger retry = 0; retry < _debugPortStatusRetryCount; ++ retry) {
        UInt32 status = [self readDebugPort:SWD_DP_STAT];
        if (status & mask) {
            return;
        }
    }
    @throw [NSException exceptionWithName:@"status error" reason:@"status timeout" userInfo:nil];
}

- (NSString *)getDebugPortStatusMessage:(UInt32)status
{
    NSMutableString *message = [NSMutableString string];
    if (status & SWD_DP_STAT_WDATAERR) {
        [message appendString:@"write data error, "];
    }
    if (status & SWD_DP_STAT_STICKYERR) {
        [message appendString:@"sticky error, "];
    }
    if (status & SWD_DP_STAT_STICKYORUN) {
        [message appendString:@"sticky overrun, "];
    }
    return [message substringToIndex:message.length - 2];
}

- (void)checkDebugPortStatus
{
    UInt32 status = [self readDebugPort:SWD_DP_STAT];
    if (!(status & (SWD_DP_STAT_WDATAERR | SWD_DP_STAT_STICKYERR | SWD_DP_STAT_STICKYORUN))) {
        return;
    }
    
    FDLog(@"attempting to recover from debug port status: %@", [self getDebugPortStatusMessage:status]);
    [self writeDebugPort:SWD_DP_ABORT value:
     SWD_DP_ABORT_ORUNERRCLR |
     SWD_DP_ABORT_WDERRCLR |
     SWD_DP_ABORT_STKERRCLR |
     SWD_DP_ABORT_STKCMPCLR];
    
    UInt32 recoveryStatus = [self readDebugPort:SWD_DP_STAT];
    if (status & (SWD_DP_STAT_WDATAERR | SWD_DP_STAT_STICKYERR | SWD_DP_STAT_STICKYORUN)) {
        FDLog(@"debug port status recovery failed: %@", [self getDebugPortStatusMessage:recoveryStatus]);
    }
}

- (void)accessPortBankSelect:(UInt8)registerOffset
{
    [self writePort:SWDDebugPort registerOffset:SWD_DP_SELECT value:registerOffset];
}

- (UInt32)readAccessPort:(UInt8)registerOffset
{
    [self writePort:SWDDebugPort registerOffset:SWD_DP_SELECT value:registerOffset & 0xf0]; // bank select
    [self readPort:SWDAccessPort registerOffset:registerOffset];
    return [self readPort:SWDDebugPort registerOffset:SWD_DP_RDBUFF];
}

- (void)writeAccessPort:(UInt8)registerOffset value:(UInt32)value
{
    [self writePort:SWDDebugPort registerOffset:SWD_DP_SELECT value:registerOffset & 0xf0]; // bank select
    [self writePort:SWDAccessPort registerOffset:registerOffset value:value];
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:0x00 bitCount:8]; // flush
}

- (void)setOverrunDetection:(bool)enabled
{
    [self writeDebugPort:SWD_DP_ABORT value:
     SWD_DP_ABORT_ORUNERRCLR |
     SWD_DP_ABORT_WDERRCLR |
     SWD_DP_ABORT_STKERRCLR |
     SWD_DP_ABORT_STKCMPCLR];
    
    UInt32 value = SWD_DP_CTRL_CDBGPWRUPREQ | SWD_DP_CTRL_CSYSPWRUPREQ;
    if (enabled) {
        value |= SWD_DP_STAT_ORUNDETECT;
    }
    [self writeDebugPort:SWD_DP_CTRL value:value];
    
    _overrunDetectionEnabled = enabled;
}

- (UInt32)readMemory:(UInt32)address
{
    [self writeAccessPort:SWD_AP_TAR value:address];
    return [self readAccessPort:SWD_AP_DRW];
}

- (void)writeMemory:(UInt32)address value:(UInt32)value
{
    [self writeAccessPort:SWD_AP_TAR value:address];
    [self writeAccessPort:SWD_AP_DRW value:value];
}

- (UInt32)readCPUID
{
    return [self readMemory:SWD_MEMORY_CPUID];
}

- (void)halt
{
    [self writeMemory:SWD_MEMORY_DHCSR value:SWD_DHCSR_DBGKEY | SWD_DHCSR_CTRL_DEBUGEN |
     SWD_DHCSR_CTRL_HALT];
}

- (void)step
{
    [self writeMemory:SWD_MEMORY_DHCSR value:SWD_DHCSR_DBGKEY | SWD_DHCSR_CTRL_DEBUGEN |
     SWD_DHCSR_CTRL_STEP | SWD_DHCSR_CTRL_MASKINTS];
}

- (void)run
{
    [self writeMemory:SWD_MEMORY_DHCSR value:SWD_DHCSR_DBGKEY | SWD_DHCSR_CTRL_DEBUGEN |
     SWD_DHCSR_CTRL_MASKINTS];
}

- (void)waitForRegisterReady
{
    for (NSUInteger retry = 0; retry < _registerRetryCount; ++retry) {
        UInt32 dhscr = [self readMemory:SWD_MEMORY_DHCSR];
        if (dhscr & SWD_DHCSR_STAT_REGRDY) {
            return;
        }
    }
    @throw [NSException exceptionWithName:@"register I/O error" reason:@"not ready" userInfo:nil];
}

- (UInt32)readRegister:(UInt16)registerID
{
    [self writeMemory:SWD_MEMORY_DCRSR value:registerID];
    [self waitForRegisterReady];
    return [self readMemory:SWD_MEMORY_DCRDR];
}

- (void)writeRegister:(UInt16)registerID value:(UInt32)value
{
    [self writeMemory:SWD_MEMORY_DCRDR value:value];
    [self writeMemory:SWD_MEMORY_DCRSR value:0x00010000 | registerID];
    [self waitForRegisterReady];
}

- (void)initializeDebugAccessPort
{
    [self readDebugPort:SWD_DP_STAT];
    
    [self writeDebugPort:SWD_DP_ABORT value:
     SWD_DP_ABORT_ORUNERRCLR |
     SWD_DP_ABORT_WDERRCLR |
     SWD_DP_ABORT_STKERRCLR |
     SWD_DP_ABORT_STKCMPCLR];

    [self readDebugPort:SWD_DP_STAT];

    [self writeDebugPort:SWD_DP_CTRL value:SWD_DP_CTRL_CDBGPWRUPREQ | SWD_DP_CTRL_CSYSPWRUPREQ];
    
    [self waitForDebugPortStatus:SWD_DP_CTRL_CSYSPWRUPACK];
    [self waitForDebugPortStatus:SWD_DP_CTRL_CDBGPWRUPACK];
    
    [self writeDebugPort:SWD_DP_SELECT value:0];
    [self writeDebugPort:SWD_AP_CSW value:
     SWD_AP_CSW_DBGSWENABLE |
     SWD_AP_CSW_MASTER_DEBUG |
     SWD_AP_CSW_HPROT |
     SWD_AP_CSW_INCREMENT_SINGLE |
     SWD_AP_CSW_32BIT];
    
    [self checkDebugPortStatus];
}

@end
