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

// Debug Port (DP)

#define SWD_DPID 0x2ba01477

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

// Authentication Access Port (AAP)

#define SWD_AAP_CMD 0x00
#define SWD_AAP_CMDKEY 0x04
#define SWD_AAP_STATUS 0x08
#define SWD_AAP_IDR 0xfc

#define SWD_AAP_CMD_SYSRESETREQ 0x00000002
#define SWD_AAP_CMD_DEVICEERASE 0x00000001

#define SWD_AAP_CMDKEY_WRITEEN 0xcfacc118

#define SWD_AAP_STATUS_ERASEBUSY 0x00000001

#define SWD_AAP_ID 0x16e60001  // Device is locked

// Advanced High-Performance Bus Access Port (AHB_AP or just AP)

#define SWD_AHB_AP_ID 0x24770011  // Device is unlocked

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
@property NSUInteger gpioResetBit;
@property NSUInteger gpioIndicatorBit;
@property NSUInteger gpioDetectBit;

@property NSUInteger ackWaitRetryCount;
@property NSUInteger debugPortStatusRetryCount;
@property NSUInteger registerRetryCount;
@property NSUInteger recoveryRetryCount;

@property BOOL overrunDetectionEnabled;
@property UInt32 tarIncrementBits;

@end

@implementation FDSerialWireDebug

// ADBUS0 OUT TCK
// ADBUS1 OUT TDI
// ADBUS2  IN TDO
// ADBUS3 OUT TMS
// ADBUS4 OUT ?
// ADBUS5  IN TARGET DETECT (target is present if 0)
// ADBUS6  IN TSRST
// ADBUS7  IN !RTCK
// ACBUS0 OUT !TRST
// ACBUS1 OUT !TSRST
// ACBUS2 OUT TRST
// ACBUS3 OUT LED

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
        
        _gpioDirections = 0b0000111100011011;
        _gpioOutputs = 0b0000001000000000;
        _gpioWriteBit = 3;
        _gpioResetBit = 9;
        _gpioIndicatorBit = 11;
        _gpioDetectBit = 5;
        
        _ackWaitRetryCount = 3;
        _debugPortStatusRetryCount = 3;
        _registerRetryCount = 3;
        _recoveryRetryCount = 5;
        
        _tarIncrementBits = 0x3ff;
    }
    return self;
}

- (void)initialize
{
    @try {
        [_serialEngine read];
    } @catch (NSException *e) {
        FDLog(@"unexpected exception: %@", e);
    }
    
    [_serialEngine setLoopback:false];
    [_serialEngine setClockDivisor:5];
    [_serialEngine write];
    
    [_serialEngine setLatencyTimer:2];
    [_serialEngine setMPSEEBitMode];
    [_serialEngine reset];
    
    [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    [_serialEngine sendImmediate];
    [_serialEngine write];
    
    [self getGpios];
}

- (void)getGpios
{
    [_serialEngine getLowByte];
    [_serialEngine getHighByte];
    [_serialEngine sendImmediate];
    [_serialEngine write];
    NSData *data = [_serialEngine read:2];
    UInt8 *bytes = (UInt8 *)data.bytes;
    _gpioInputs = (bytes[1] << 8) | bytes[0];
}

- (BOOL)getGpioDetect
{
    [self getGpios];
    return _gpioInputs & (1 << _gpioDetectBit) ? NO : YES;
}

- (void)setGpioBit:(NSUInteger)bit value:(BOOL)value
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
    _gpioOutputs = outputs;
    if (mask & 0x00ff) {
        [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    } else {
        [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    }
}

- (void)setGpioIndicator:(BOOL)value
{
    [self setGpioBit:_gpioIndicatorBit value:value];
}

- (void)setGpioReset:(BOOL)value
{
    [self setGpioBit:_gpioResetBit value:value];
}

- (void)turnToWrite
{
    [self setGpioBit:_gpioWriteBit value:true];
}

- (void)turnToRead
{
    [self setGpioBit:_gpioWriteBit value:false];
}

- (void)skip:(NSUInteger)n
{
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:0 bitCount:n];
}

- (void)turnToWriteAndSkip
{
    [self turnToWrite];
    [self skip:1];
}

- (void)turnToReadAndSkip
{
    [self turnToRead];
    [self skip:1];
}

- (void)resetDebugPort
{
    [self turnToWrite];
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
    UInt8 request = 0b10000001; // Start (bit 0) & Park (bit 7)
    if (port == SWDAccessPort) {
        request |= 0b00000010;
    }
    if (direction == SWDReadDirection) {
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
    [self turnToRead];
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
    BOOL parity = bytes[4] >> 7;
    if (parity != [self getParityUInt32:value]) {
        @throw [NSException exceptionWithName:@"read error" reason:@"parity mismatch" userInfo:nil];
    }
    return value;
}

- (void)writeUInt32:(UInt32)value
{
    UInt8 bytes[] = {value, value >> 8, value >> 16, value >> 24};
    [_serialEngine shiftOutDataLSBFirstNegativeEdge:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
    UInt8 parity = [self getParityUInt32:value];
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:parity bitCount:1];
}

- (UInt32)readPort:(SWDPort)port registerOffset:(UInt8)registerOffset
{
//    NSLog(@"read  %@ %02x", port == SWDDebugPort ? @"dp" : @"ap", registerOffset);
    UInt8 request = [self encodeRequestPort:port direction:SWDReadDirection address:registerOffset];
    for (NSUInteger retry = 0; retry < _ackWaitRetryCount; ++retry) {
        SWDAck ack = [self request:request];
        UInt32 value;
        if (_overrunDetectionEnabled) {
            value = [self readUInt32];
            [self turnToWriteAndSkip];
        }
        if (ack == SWDOKAck) {
            if (!_overrunDetectionEnabled) {
                value = [self readUInt32];
                [self turnToWriteAndSkip];
            }
//            NSLog(@"read  %@ %02x = %08x", port == SWDDebugPort ? @"dp" : @"ap", registerOffset, value);
            return value;
        }
        if (!_overrunDetectionEnabled) {
            [self turnToWriteAndSkip];
        }
        if (ack != SWDWaitAck) {
            @throw [NSException exceptionWithName:@"read port error" reason:@"unexpected ack" userInfo:nil];
        }
    }
    @throw [NSException exceptionWithName:@"read port error" reason:@"too many retries" userInfo:nil];
}

- (void)writePort:(SWDPort)port registerOffset:(UInt8)registerOffset value:(UInt32)value
{
//    NSLog(@"write %@ %02x = %08x", port == SWDDebugPort ? @"dp" : @"ap", registerOffset, value);
    UInt8 request = [self encodeRequestPort:port direction:SWDWriteDirection address:registerOffset];
    for (NSUInteger retry = 0; retry < _ackWaitRetryCount; ++retry) {
        SWDAck ack = [self request:request];
        [self turnToWriteAndSkip];
        if (_overrunDetectionEnabled) {
            [self writeUInt32:value];
        }
        if (ack == SWDOKAck) {
            if (!_overrunDetectionEnabled) {
                [self writeUInt32:value];
            }
//            NSLog(@"write %@ %02x = %08x done", port == SWDDebugPort ? @"dp" : @"ap", registerOffset, value);
            return;
        }
        if (ack != SWDWaitAck) {
            @throw [NSException exceptionWithName:@"write port error" reason:[NSString stringWithFormat:@"unexpected ack %u writing to port %u, register offset %d, value 0x%08x", ack, port, registerOffset, value] userInfo:nil];
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
    if (recoveryStatus & (SWD_DP_STAT_WDATAERR | SWD_DP_STAT_STICKYERR | SWD_DP_STAT_STICKYORUN)) {
        FDLog(@"debug port status recovery failed: %@", [self getDebugPortStatusMessage:recoveryStatus]);
    }
    
    [self writeDebugPort:SWD_DP_SELECT value:0];
    
    [self writeAccessPort:SWD_AP_CSW value:
     SWD_AP_CSW_DBGSWENABLE |
     SWD_AP_CSW_MASTER_DEBUG |
     SWD_AP_CSW_HPROT |
     SWD_AP_CSW_INCREMENT_SINGLE |
     SWD_AP_CSW_32BIT];
}

- (void)recoverFromDebugPortError
{
    [self resetDebugPort];
    UInt32 debugPortIDCode = [self readDebugPortIDCode];
    NSLog(@"DPID = %08x", debugPortIDCode);
    [self checkDebugPortStatus];
}

- (void)accessPortBankSelect:(UInt8)registerOffset
{
    [self writePort:SWDDebugPort registerOffset:SWD_DP_SELECT value:registerOffset & 0xf0];
}

- (UInt32)readAccessPort:(UInt8)registerOffset
{
//    NSLog(@"read access port %02x", registerOffset);
    [self accessPortBankSelect:registerOffset];
    [self readPort:SWDAccessPort registerOffset:registerOffset];
    uint32_t value = [self readPort:SWDDebugPort registerOffset:SWD_DP_RDBUFF];
//    NSLog(@"read access port %02x = %08x", registerOffset, value);
    return value;
}

- (void)flush
{
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:0x00 bitCount:8];
}

- (void)writeAccessPort:(UInt8)registerOffset value:(UInt32)value
{
//    NSLog(@"write access port %02x = %08x", registerOffset, value);
    [self accessPortBankSelect:registerOffset];
    [self writePort:SWDAccessPort registerOffset:registerOffset value:value];
    [self flush];
//    NSLog(@"write access port %02x = %08x done", registerOffset, value);
}

- (void)recoverAndRetry:(void (^)(void))block
{
    for (NSUInteger i = 0; i < _recoveryRetryCount; ++i) {
        @try {
            block();
            break;
        } @catch (NSException *e) {
            if (i == (_recoveryRetryCount - 1)) {
                @throw;
            }
            FDLog(@"unexpected exception (attempting recovery): %@", e);
            [self recoverFromDebugPortError];
        }
    }
}

- (UInt32)readMemory:(UInt32)address
{
//    NSLog(@"read memory %08x", address);
    __block UInt32 value;
    [self recoverAndRetry:^(void) {
        [self writeAccessPort:SWD_AP_TAR value:address];
        value = [self readAccessPort:SWD_AP_DRW];
    }];
    return value;
}

- (void)writeMemory:(UInt32)address value:(UInt32)value
{
//    NSLog(@"write memory %08x = %08x", address, value);
    [self recoverAndRetry:^(void) {
        [self writeAccessPort:SWD_AP_TAR value:address];
        [self writeAccessPort:SWD_AP_DRW value:value];
    }];
//    NSLog(@"write memory %08x = %08x done", address, value);
}

- (void)setOverrunDetection:(BOOL)enabled
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

static UInt32 unpackLittleEndianUInt32(uint8_t *bytes) {
    return (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
}

- (void)beforeMemoryTransfer:(UInt32)address length:(NSUInteger)length
{
    if ((address & 0x3) != 0) {
        @throw [NSException exceptionWithName:@"invalid address"
                                       reason:[NSString stringWithFormat:@"invalid address: %08x", address]
                                     userInfo:nil];
    }
    if ((length == 0) || ((length & 0x3) != 0)) {
        @throw [NSException exceptionWithName:@"invalid length"
                                       reason:[NSString stringWithFormat:@"invalid length: %lu", (unsigned long int)length]
                                     userInfo:nil];
    }
    // TAR auto increment is only guaranteed in the first 10-bits (beyond that is implementation defined)
    UInt32 endAddress = (UInt32) (address + length - 1);
    if ((address & ~_tarIncrementBits) != (endAddress & ~_tarIncrementBits)) {
        @throw [NSException exceptionWithName:@"invalid address range"
                                       reason:[NSString stringWithFormat:@"invalid address range: %08x to %08x", address, endAddress]
                                     userInfo:nil];
    }
    
    [self writeAccessPort:SWD_AP_TAR value:address];
    [self accessPortBankSelect:SWD_AP_DRW];
    [self setOverrunDetection:true];
}

- (void)afterMemoryTransfer
{
    uint32_t status = [self readDebugPort:SWD_DP_STAT];
    [self setOverrunDetection:false];
    if (status & (SWD_DP_STAT_WDATAERR | SWD_DP_STAT_STICKYERR | SWD_DP_STAT_STICKYORUN)) {
        @throw [NSException exceptionWithName:@"sticky error"
                                       reason:[NSString stringWithFormat:@"sticky error after block transfer: %@", [self getDebugPortStatusMessage:status]]
                                     userInfo:nil];
    }
}

- (void)requestWriteSkip:(UInt8)request value:(UInt32)value
{
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:request bitCount:8];
    [self turnToRead];
    [self skip:4]; // skip over turn and ack
    [self turnToWriteAndSkip];
    [self writeUInt32:value];
}

- (void)writeMemoryTransfer:(UInt32)address data:(NSData *)data
{
    [self beforeMemoryTransfer:address length:data.length];
    
    uint8_t request = [self encodeRequestPort:SWDAccessPort direction:SWDWriteDirection address:SWD_AP_DRW];
    uint8_t *bytes = (uint8_t *)data.bytes;
    NSUInteger length = data.length;
    for (NSUInteger i = 0; i < length; i += 4) {
        [self requestWriteSkip:request value:unpackLittleEndianUInt32(&bytes[i])];
    }
    
    [self afterMemoryTransfer];
}

- (NSData *)readMemoryTransfer:(UInt32)address length:(UInt32)length
{
    [self beforeMemoryTransfer:address length:length];
    
    NSMutableData *data = [NSMutableData dataWithCapacity:length];

    uint8_t request = [self encodeRequestPort:SWDAccessPort direction:SWDReadDirection address:SWD_AP_DRW];
    uint32_t words = length / 4;
    // note: 1 extra iteration because of 1 read delay in getting data out
    for (NSUInteger i = 0; i <= words; ++i) {
        [_serialEngine shiftOutBitsLSBFirstNegativeEdge:request bitCount:8];
        [self turnToRead];
        [self skip:4]; // skip over turn and ack
        [_serialEngine shiftInDataLSBFirstPositiveEdge:4]; // data
        [_serialEngine shiftInBitsLSBFirstPositiveEdge:1]; // parity
        [self turnToWriteAndSkip];
    }
    [_serialEngine sendImmediate];
    
    NSData *output = [_serialEngine read:5 * (words + 1)];
    UInt8 *outputBytes = (UInt8 *)output.bytes;
    outputBytes += 5; // skip extra read data
    for (NSUInteger i = 0; i < words; ++i) {
        UInt8 *bytes = &outputBytes[i * 5];
        UInt32 value = (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
        BOOL parity = bytes[4] >> 7;
        BOOL actual = [self getParityUInt32:value];
        if (parity != actual) {
            @throw [NSException exceptionWithName:@"read error"
                                           reason:@"parity mismatch"
                                         userInfo:nil];
        }
        [data appendBytes:bytes length:4];
    }

    [self afterMemoryTransfer];

    return data;
}

- (void)paginate:(UInt32)incrementBits address:(UInt32)address length:(UInt32)length block:(void (^)(UInt32 subaddress, UInt32 offset, UInt32 sublength))block
{
    UInt32 offset = 0;
    while (length > 0) {
        UInt32 sublength = (incrementBits + 1) - (address & incrementBits);
        if (length < sublength) {
            sublength = length;
        }
        
        for (NSUInteger i = 0; i < 3; ++i) {
            @try {
                block(address, offset, sublength);
                break;
            } @catch (NSException *e) {
                if (i == 2) {
                    @throw;
                }
                [self recoverFromDebugPortError];
            }
        }
        
        address += sublength;
        length -= sublength;
        offset += sublength;
    }
}

- (void)writeMemory:(UInt32)address data:(NSData *)data
{
    [self paginate:_tarIncrementBits address:address length:(UInt32)data.length block:^(UInt32 subaddress, UInt32 offset, UInt32 sublength) {
        [self writeMemoryTransfer:subaddress data:[data subdataWithRange:NSMakeRange(offset, sublength)]];
    }];
}

- (NSData *)readMemory:(UInt32)address length:(UInt32)length
{
    uint32_t readAddress = address & ~0x03;
    uint32_t readLength = length + (address & 0x03);
    readLength += (4 - (readLength & 0x3)) & 0x03;
    NSMutableData *data = [NSMutableData dataWithCapacity:readLength];
    [self paginate:_tarIncrementBits address:readAddress length:readLength block:^(UInt32 subaddress, UInt32 offset, UInt32 sublength) {
        [data appendData:[self readMemoryTransfer:subaddress length:sublength]];
    }];
    return [data subdataWithRange:NSMakeRange(address - readAddress, length)];
}

- (UInt8)readMemoryUInt8:(UInt32)address
{
    UInt32 word = [self readMemory:address & ~0x3];
    return (word >> ((address & 0x3) * 8)) & 0xff;
}

- (UInt16)readMemoryUInt16:(UInt32)address
{
    UInt32 word = [self readMemory:address & ~0x3];
    return (word >> ((address & 0x2) * 8)) & 0xffff;
}

#define MSC 0x400c0000

#define MSC_WRITECTRL (MSC + 0x008)
#define MSC_WRITECMD  (MSC + 0x00c)
#define MSC_ADDRB     (MSC + 0x010)
#define MSC_WDATA     (MSC + 0x018)
#define MSC_STATUS    (MSC + 0x01c)
#define MSC_MASSLOCK  (MSC + 0x054)

#define MSC_WRITECTRL_WREN BIT(0)

#define MSC_WRITECMD_LADDRIM    BIT(0)
#define MSC_WRITECMD_ERASEPAGE  BIT(1)
#define MSC_WRITECMD_WRITEEND   BIT(2)
#define MSC_WRITECMD_WRITEONCE  BIT(3)
#define MSC_WRITECMD_WRITETRIG  BIT(4)
#define MSC_WRITECMD_ERASEABORT BIT(5)
#define MSC_WRITECMD_ERASEMAIN0 BIT(8)
#define MSC_WRITECMD_ERASEMAIN1 BIT(9)
#define MSC_WRITECMD_CLEARWDATA BIT(12)

#define MSC_STATUS_BUSY       BIT(0)
#define MSC_STATUS_LOCKED     BIT(1)
#define MSC_STATUS_INVADDR    BIT(2)
#define MSC_STATUS_WDATAREADY BIT(3)

#define MSC_MASSLOCK_UNLOCK 0x631a

- (void)memorySystemControllerStatusWait:(UInt32)mask value:(UInt32)value
{
    NSTimeInterval timeout = 0.250;
    NSDate *start = [NSDate date];
    NSDate *now;
    do {
        UInt32 status = [self readMemory:MSC_STATUS];
        if ((status & mask) != value) {
            return;
        }
        
        [NSThread sleepForTimeInterval:0.0001];
        now = [NSDate date];
    } while ([now timeIntervalSinceDate:start] < timeout);
    [NSException exceptionWithName:@"timeout"reason:@"timeout" userInfo:nil];
}

- (void)loadAddress:(UInt32)address
{
    [self writeMemory:MSC_WRITECTRL value:MSC_WRITECTRL_WREN];
    [self writeMemory:MSC_ADDRB value:address];
    [self writeMemory:MSC_WRITECMD value:MSC_WRITECMD_LADDRIM];
    UInt32 status = [self readMemory:MSC_STATUS];
    if (status & (MSC_STATUS_INVADDR | MSC_STATUS_LOCKED)) {
        NSLog(@"fail");
    }
}

- (void)erase:(UInt32)address
{
    [self recoverAndRetry:^(void) {
        [self loadAddress:address];
        [self writeMemory:MSC_WRITECMD value:MSC_WRITECMD_ERASEPAGE];
        [self memorySystemControllerStatusWait:MSC_STATUS_BUSY value:MSC_STATUS_BUSY];
    }];
}

- (void)massErase
{
    [self recoverAndRetry:^(void) {
        [self writeMemory:MSC_WRITECTRL value:MSC_WRITECTRL_WREN];
        [self writeMemory:MSC_MASSLOCK value:MSC_MASSLOCK_UNLOCK];
        [self writeMemory:MSC_WRITECMD value:MSC_WRITECMD_ERASEMAIN0];
        [self memorySystemControllerStatusWait:MSC_STATUS_BUSY value:MSC_STATUS_BUSY];
    }];
}

- (void)flashTransfer:(UInt32)address data:(NSData *)data
{
    if ((address & 0x3) != 0) {
        @throw [NSException exceptionWithName:@"invalid address"
                                       reason:[NSString stringWithFormat:@"invalid address: %08x", address]
                                     userInfo:nil];
    }
    UInt32 length = (UInt32)data.length;
    if ((length == 0) || ((length & 0x3) != 0)) {
        @throw [NSException exceptionWithName:@"invalid length"
                                       reason:[NSString stringWithFormat:@"invalid length: %lu", (unsigned long int)length]
                                     userInfo:nil];
    }

    BOOL fast = NO;
    if (fast) {
        [self accessPortBankSelect:0x00];
        [self setOverrunDetection:true];
    }
    
    UInt8 apTarRequest = [self encodeRequestPort:SWDAccessPort direction:SWDWriteDirection address:SWD_AP_TAR];
    UInt8 apDrwRequest = [self encodeRequestPort:SWDAccessPort direction:SWDWriteDirection address:SWD_AP_DRW];
    UInt8 *bytes = (UInt8 *)data.bytes;
    for (NSUInteger i = 0; i < length; i += 4) {
        UInt32 value = unpackLittleEndianUInt32(&bytes[i]);
        if (fast) {
// We don't need the two way status waits, because going over USB via FTDI, etc
// is slower than the operations take. -denis
            [self requestWriteSkip:apTarRequest value:MSC_WDATA];
            [self requestWriteSkip:apDrwRequest value:value];
            [self requestWriteSkip:apTarRequest value:MSC_WRITECMD];
            [self requestWriteSkip:apDrwRequest value:MSC_WRITECMD_WRITETRIG];
        } else {
            [self loadAddress:(uint32_t)(address + i)];
            [self memorySystemControllerStatusWait:MSC_STATUS_WDATAREADY value:0];
            [self writeMemory:MSC_WDATA value:value];
            [self writeMemory:MSC_WRITECMD value:MSC_WRITECMD_WRITEONCE];
            [self memorySystemControllerStatusWait:MSC_STATUS_BUSY value:MSC_STATUS_BUSY];
        }
    }
    
    if (fast) {
        [self flush];
        [self afterMemoryTransfer];
    }
}

- (void)flash:(UInt32)address data:(NSData *)data
{
    [self paginate:0x7ff address:address length:(UInt32)data.length block:^(UInt32 subaddress, UInt32 offset, UInt32 sublength) {
        [self flashTransfer:subaddress data:[data subdataWithRange:NSMakeRange(offset, sublength)]];
    }];
}

#define FP_CTRL 0xE0002000
#define FP_REMAP 0xE0002004
#define FP_COMP0 0xE0002008
#define FP_COMP1 0xE000200C
#define FP_COMP2 0xE0002010
#define FP_COMP3 0xE0002014
#define FP_COMP4 0xE0002018
#define FP_COMP5 0xE000201C
#define FP_COMP6 0xE0002020
#define FP_COMP7 0xE0002024
#define PID4 0xE0002FD0
#define PID5 0xE0002FD4
#define PID6 0xE0002FD8
#define PID7 0xE0002FDC
#define PID0 0xE0002FE0
#define PID1 0xE0002FE4
#define PID2 0xE0002FE8
#define PID3 0xE0002FEC
#define CID0 0xE0002FF0
#define CID1 0xE0002FF4
#define CID2 0xE0002FF8
#define CID3 0xE0002FFC

#define FP_CTRL_KEY    BIT(1)
#define FP_CTRL_ENABLE BIT(0)

#define FP_COMP_REPLACE_U 0x80000000
#define FP_COMP_REPLACE_L 0x40000000
#define FP_COMP_ADDRESS 0x1ffffffc
#define FP_COMP_ENABLE BIT(0)

- (uint32_t)breakpointCount
{
    uint32_t value = [self readMemory:FP_CTRL];
    uint32_t numCode = ((value >> 8) & 0x70) | ((value >> 4) & 0xf);
    return numCode;
}

- (void)enableBreakpoints:(BOOL)enable
{
    [self writeMemory:FP_CTRL value:FP_CTRL_KEY | (enable ? FP_CTRL_ENABLE : 0)];
}

- (BOOL)getBreakpoint:(uint32_t)n address:(uint32_t *)address
{
    uint32_t value = [self readMemory:FP_COMP0 + n * 4];
    if (value & FP_COMP_ENABLE) {
        *address = (value & FP_COMP_ADDRESS) | ((value & FP_COMP_REPLACE_U) ? 0x2 : 0x0);
        return true;
    }
    return false;
}

- (void)setBreakpoint:(uint32_t)n address:(uint32_t)address
{
    uint32_t value = ((address & 0x2) ? FP_COMP_REPLACE_U : FP_COMP_REPLACE_L) | (address & ~0x3) | FP_COMP_ENABLE;
    [self writeMemory:FP_COMP0 + n * 4 value:value];
}

- (void)disableBreakpoint:(uint32_t)n
{
    [self writeMemory:FP_COMP0 + n * 4 value:0];
}

- (void)disableAllBreakpoints
{
    uint32_t count = [self breakpointCount];
    for (uint32_t i = 0; i < count; ++i) {
        [self disableBreakpoint:i];
    }
}

#define SCB 0xE000ED00
#define SCB_AIRCR (SCB + 0x00C)
#define SCB_AIRCR_SYSRESETREQ 0x05FA0004

- (void)reset
{
    [self writeMemory:SCB_AIRCR value:SCB_AIRCR_SYSRESETREQ];
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

- (BOOL)isHalted
{
    UInt32 dhcsr = [self readMemory:SWD_MEMORY_DHCSR];
    return dhcsr & SWD_DHCSR_STAT_HALT ? YES : NO;
}

- (void)waitForHalt:(NSTimeInterval)timeout
{
    NSDate *start = [NSDate date];
    NSDate *now;
    do {
        if ([self isHalted]) {
            return;
        }
        
        [NSThread sleepForTimeInterval:0.001];
        now = [NSDate date];
    } while ([now timeIntervalSinceDate:start] < timeout);
    @throw [NSException exceptionWithName:@"timeout"reason:@"timeout" userInfo:nil];
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
//    NSLog(@"read register %04x", registerID);
    [self writeMemory:SWD_MEMORY_DCRSR value:registerID];
    [self waitForRegisterReady];
    uint32_t value = [self readMemory:SWD_MEMORY_DCRDR];
//    NSLog(@"read register %04x = %08x", registerID, value);
    return value;
}

- (void)writeRegister:(UInt16)registerID value:(UInt32)value
{
//    NSLog(@"write register %04x = %08x", registerID, value);
    [self writeMemory:SWD_MEMORY_DCRDR value:value];
    [self writeMemory:SWD_MEMORY_DCRSR value:0x00010000 | registerID];
    [self waitForRegisterReady];
//    NSLog(@"write register %04x = %08x done", registerID, value);
}

- (void)initializeDebugPort
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

    [self readDebugPort:SWD_DP_STAT];
}

- (uint32_t)readAccessPortID
{
    return [self readAccessPort:SWD_AAP_IDR];
}

- (BOOL)isAuthenticationAccessPortActive {
    uint32_t dpid = [self readDebugPort:0];
    if (dpid != SWD_DPID) {
        @throw [NSException exceptionWithName:@"DPID_NOT_RECOGNIZED" reason:@"DPID not recognized" userInfo:nil];
    }
    
    uint32_t apid = [self readAccessPortID];
    if (apid == SWD_AHB_AP_ID) {
        return NO;
    }
    return YES;
    /*
    if (apid == SWD_AAP_ID) {
        return YES;
    }
    @throw [NSException exceptionWithName:@"APID_NOT_RECOGNIZED" reason:@"APID not recognized" userInfo:nil];
     */
}

#define SWD_AAP_ERASE_TIMEOUT 0.200 // erase takes 125 ms

- (void)authenticationAccessPortErase
{
    [self writeAccessPort:SWD_AAP_CMDKEY value:SWD_AAP_CMDKEY_WRITEEN];
    [self writeAccessPort:SWD_AAP_CMD value:SWD_AAP_CMD_DEVICEERASE];
    NSDate *start = [NSDate date];
    do {
        [NSThread sleepForTimeInterval:0.025];
        uint32_t status = [self readAccessPort:SWD_AAP_STATUS];
        if ((status & SWD_AAP_STATUS_ERASEBUSY) == 0) {
            break;
        }
    } while ([[NSDate date] timeIntervalSinceDate:start] < SWD_AAP_ERASE_TIMEOUT);
}

- (void)authenticationAccessPortReset
{
    [self writeAccessPort:SWD_AAP_CMD value:SWD_AAP_CMD_SYSRESETREQ];
}

- (void)initializeAccessPort
{
    [self writeAccessPort:SWD_AP_CSW value:
     SWD_AP_CSW_DBGSWENABLE |
     SWD_AP_CSW_MASTER_DEBUG |
     SWD_AP_CSW_HPROT |
     SWD_AP_CSW_INCREMENT_SINGLE |
     SWD_AP_CSW_32BIT];
    
    [self checkDebugPortStatus];
}

@end
