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

@protocol FDUSBMonitorMatcher <NSObject>

- (BOOL)matches:(IOUSBDeviceInterface **)deviceInterface;

@end

@interface FDUSBMonitorMatcherVidPid : NSObject<FDUSBMonitorMatcher>

+ (FDUSBMonitorMatcherVidPid *)matcher:(NSString *)name vid:(uint16_t)vid pid:(uint16_t)pid;

@property NSString *name;
@property uint16_t vid;
@property uint16_t pid;

@end

@interface FDUSBMonitor : NSObject

@property NSArray *matchers;
@property UInt16 vendor;
@property UInt16 product;

@property id<FDUSBMonitorDelegate> delegate;
@property FDLogger *logger;

@property (readonly) NSArray *devices;

- (void)start;

- (FDUSBDevice *)deviceWithLocation:(NSObject *)location;

@end
