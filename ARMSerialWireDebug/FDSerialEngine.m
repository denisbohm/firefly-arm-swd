//
//  FDSerialEngine.m
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDSerialEngine.h"
#import "FDUSBDevice.h"

@interface FDSerialEngine () <FDUSBDeviceDelegate>

@property UInt8 readPipe;
@property UInt8 writePipe;

@property NSData *readData;
@property NSCondition *readCondition;

@property NSMutableData *writeData;

@end

#define REQUEST_RESET 0x00
#define REQUEST_SET_LATENCY_TIMER 0x09
#define REQUEST_GET_LATENCY_TIMER 0x0a
#define REQUEST_SET_BITMODE 0x0b

#define REQUEST_RESET_VALUE_PURGE_RX 0x01
#define REQUEST_RESET_VALUE_PURGE_TX 0x02

@implementation FDSerialEngine

- (id)init
{
    if (self = [super init]) {
        _timeout = 0.5;
        _readPipe = 1;
        _writePipe = 2;
        _writeData = [NSMutableData data];
        _readCondition = [[NSCondition alloc] init];
    }
    return self;
}

- (void)reset
{
    [_usbDevice request:REQUEST_RESET value:REQUEST_RESET_VALUE_PURGE_RX | REQUEST_RESET_VALUE_PURGE_TX];
}

- (void)setLatencyTimer:(UInt16)value
{
    [_usbDevice request:REQUEST_SET_LATENCY_TIMER value:value];
}

- (void)setResetMode
{
    [_usbDevice request:REQUEST_SET_BITMODE value:0x000b];
}

- (void)setMPSEEBitMode
{
    [_usbDevice request:REQUEST_SET_BITMODE value:0x020b];
}

- (void)setLoopback:(bool)enable
{
    UInt8 bytes[] = {enable ? 0x84 : 0x85};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)setClockDivisor:(UInt16)divisor
{
    UInt8 bytes[] = {0x86, divisor, divisor >> 8};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)setLowByte:(UInt8)value direction:(UInt8)direction
{
    UInt8 bytes[] = {0x80, value, direction};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)getLowByte
{
    UInt8 bytes[] = {0x81};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)setHighByte:(UInt8)value direction:(UInt8)direction
{
    UInt8 bytes[] = {0x82, value, direction};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)getHighByte
{
    UInt8 bytes[] = {0x83};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)sendImmediate
{
    UInt8 bytes[] = {0x87};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)shiftOutBitsLSBFirstNegativeEdge:(UInt8)byte bitCount:(NSUInteger)bitCount
{
    UInt8 bytes[] = {0x1b, bitCount - 1, byte};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)shiftOutUInt32LSBFirstNegativeEdge:(UInt32)word
{
    UInt8 bytes[] = {0x19, 3, 0, word, word >> 8, word >> 16, word >> 24};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)shiftOutDataLSBFirstNegativeEdge:(NSData *)data
{
    NSUInteger count = data.length - 1;
    UInt8 bytes[] = {0x19, count, count >> 8};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
    [_writeData appendData:data];
}

- (void)shiftInBitsLSBFirstPositiveEdge:(NSUInteger)bitCount
{
    UInt8 bytes[] = {0x2a, bitCount - 1};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)shiftInUInt32LSBFirstPositiveEdge
{
    UInt8 bytes[] = {0x28, 3, 0};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)shiftInDataLSBFirstPositiveEdge:(NSUInteger)byteCount
{
    NSUInteger count = byteCount - 1;
    UInt8 bytes[] = {0x28, count, count >> 8};
    [_writeData appendBytes:bytes length:sizeof(bytes)];
}

- (void)usbDevice:(FDUSBDevice *)usbDevice writePipeAsync:(NSData *)data error:(NSError *)error
{
}

- (void)write
{
    if (_writeData.length == 0) {
        return;
    }
//    NSLog(@"write %@", _writeData);
    [_usbDevice writePipe:_writePipe data:_writeData];
    _writeData = nil;
    _writeData = [NSMutableData data];
}

- (void)usbDevice:(FDUSBDevice *)usbDevice readPipeAsync:(NSData *)data error:(NSError *)error
{
    [_readCondition lock];
    self.readData = data;
    [_readCondition broadcast];
    [_readCondition unlock];
}

- (NSData *)read
{
    NSData *data = nil;
    if (_timeout) {
        [_readCondition lock];
        self.readData = nil;
        _usbDevice.delegate = self;
        [_usbDevice readPipeAsync:_readPipe length:4096];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:_timeout];
        if (![_readCondition waitUntilDate:deadline]) {
            [_readCondition unlock];
            @throw [NSException exceptionWithName:@"USBReadTimeout" reason:@"USB read timeout" userInfo:nil];
        }
        data = self.readData;
        self.readData = nil;
        [_readCondition unlock];
    } else {
        data = [_usbDevice readPipe:_readPipe length:4096];        
    }
    
//    NSLog(@"read %@", data);
    return [data subdataWithRange:NSMakeRange(2, data.length - 2)];
}

- (NSData *)read:(UInt32)length
{
    [self write];
    
    NSMutableData *data = [NSMutableData dataWithCapacity:2 + length];
    while (data.length < length) {
        NSData *subdata = [self read];
        [data appendData:subdata];
    }
    return data;
}

@end
