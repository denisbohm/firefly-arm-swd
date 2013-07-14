//
//  FDUSBMonitor.h
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDUSBDevice;
@class FDLogger;
@class FDUSBMonitor;

@protocol FDUSBMonitorDelegate <NSObject>

- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceAdded:(FDUSBDevice *)usbDevice;
- (void)usbMonitor:(FDUSBMonitor *)usbMonitor usbDeviceRemoved:(FDUSBDevice *)usbDevice;

@end

@interface FDUSBMonitor : NSObject

@property UInt16 vendor;
@property UInt16 product;

@property id<FDUSBMonitorDelegate> delegate;
@property FDLogger *logger;

- (void)start;

@end
