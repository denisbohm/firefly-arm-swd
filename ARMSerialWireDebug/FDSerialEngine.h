//
//  FDSerialEngine.h
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDUSBDevice;

@interface FDSerialEngine : NSObject

@property FDUSBDevice *usbDevice;
@property NSMutableData *writeData;

- (void)reset;
- (void)setLatencyTimer:(UInt16)value;
- (void)setMPSEEBitMode;

- (void)setLoopback:(bool)enable;
- (void)setClockDivisor:(UInt16)divisor;
- (void)setLowByte:(UInt8)value direction:(UInt8)direction;
- (void)getLowByte;
- (void)setHighByte:(UInt8)value direction:(UInt8)direction;
- (void)getHighByte;
- (void)sendImmediate;
- (void)shiftOutBitsLSBFirstNegativeEdge:(UInt8)byte bitCount:(NSUInteger)bitCount;
- (void)shiftOutUInt32LSBFirstNegativeEdge:(UInt32)word;
- (void)shiftOutDataLSBFirstNegativeEdge:(NSData *)data;
- (void)shiftInBitsLSBFirstPositiveEdge:(NSUInteger)bitCount;
- (void)shiftInUInt32LSBFirstPositiveEdge;
- (void)shiftInDataLSBFirstPositiveEdge:(NSUInteger)byteCount;

- (void)write;
- (NSData *)read:(UInt32)length;

@end
