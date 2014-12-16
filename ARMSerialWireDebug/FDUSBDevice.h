//
//  FDUSBDevice.h
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <IOKit/usb/IOUSBLib.h>

@class FDLogger;
@class FDUSBDevice;

@protocol FDUSBDeviceDelegate <NSObject>

- (void)usbDevice:(FDUSBDevice *)usbDevice readPipeAsync:(NSData *)data error:(NSError *)error;
- (void)usbDevice:(FDUSBDevice *)usbDevice writePipeAsync:(NSData *)data error:(NSError *)error;

@end

@class FDUSBMonitor;

@interface FDUSBDevice : NSObject

@property FDLogger *logger;
@property FDUSBMonitor *usbMonitor;
@property io_service_t service;
@property IOUSBDeviceInterface **deviceInterface;
@property io_object_t notification;

@property id<FDUSBDeviceDelegate> delegate;

@property NSObject *location;

- (void)open;
- (void)close;

- (void)request:(UInt8)request value:(UInt16)value;

- (void)writePipe:(UInt8)pipe data:(NSData *)data;
- (void)writePipeAsync:(UInt8)pipe data:(NSData *)data;

- (NSData *)readPipe:(UInt8)pipe length:(UInt32)length;
- (void)readPipeAsync:(UInt8)pipe length:(UInt32)length;

@end
