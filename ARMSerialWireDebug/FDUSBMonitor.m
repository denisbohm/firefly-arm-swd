//
//  FDUSBMonitor.m
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDLogger.h"
#import "FDUSBDevice.h"
#import "FDUSBMonitor.h"

#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOMessage.h>
#include <IOKit/usb/IOUSBLib.h>

@interface FDUSBMonitor ()

@property IONotificationPortRef notificationPort;
@property NSMutableArray *usbDevices;
@property NSThread *thread;

@end

@implementation FDUSBMonitor

- (id)init
{
    if (self = [super init]) {
        _usbDevices = [NSMutableArray array];
    }
    return self;
}

- (void)USBDeviceRemoved:(FDUSBDevice *)usbDevice
{
    kern_return_t kernReturn = IOObjectRelease(usbDevice.notification);
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure releasing USB device notification: %08x", kernReturn);
    }
    [_usbDevices removeObject:usbDevice];
    [usbDevice close];
    [_delegate usbMonitor:self usbDeviceRemoved:usbDevice];
}

static
void USBDeviceInterest(
                       void *refCon,
                       io_service_t service,
                       natural_t messageType,
                       void *messageArgument
                       )
{
    if (messageType == kIOMessageServiceIsTerminated) {
        FDUSBDevice *usbDevice = (__bridge FDUSBDevice *)refCon;
        [usbDevice.usbMonitor USBDeviceRemoved:usbDevice];
    }
}

- (void)USBDevicesAdded:(io_iterator_t)iterator
{
    io_service_t service;
    while ((service = IOIteratorNext(iterator))) {
        IOCFPlugInInterface **plugInInterface = NULL;
        SInt32 score;
        kern_return_t kernReturn = IOCreatePlugInInterfaceForService(
                                                                     service,
                                                                     kIOUSBDeviceUserClientTypeID,
                                                                     kIOCFPlugInInterfaceID,
                                                                     &plugInInterface,
                                                                     &score
                                                                     );
        //Don’t need the device object after intermediate plug-in is created
//        kernReturn = IOObjectRelease(service);
        if ((kIOReturnSuccess != kernReturn) || !plugInInterface) {
            FDLog(@"failure IOCreatePlugInInterfaceForService: %08x", kernReturn);
            continue;
        }
        //Now create the device interface
        IOUSBDeviceInterface **deviceInterface = NULL;
        HRESULT result = (*plugInInterface)->QueryInterface(
                                                            plugInInterface,
                                                            CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                                                            (LPVOID *)&deviceInterface
                                                            );
        //Don’t need the intermediate plug-in after device interface
        //is created
        (*plugInInterface)->Release(plugInInterface);
        if (result || !deviceInterface) {
            printf("Couldn’t create a device interface (%08x)\n", (int) result);
            continue;
        }
        //Check these values for confirmation
        UInt16 vendor;
        kernReturn = (*deviceInterface)->GetDeviceVendor(deviceInterface, &vendor);
        if (kernReturn != kIOReturnSuccess) {
            FDLog(@"failure GetDeviceVendor: %08x", kernReturn);
        }
        UInt16 product;
        kernReturn = (*deviceInterface)->GetDeviceProduct(deviceInterface, &product);
        if (kernReturn != kIOReturnSuccess) {
            FDLog(@"failure GetDeviceProduct: %08x", kernReturn);
        }
        if ((vendor != self.vendor) || (product != self.product)) {
            (void) (*deviceInterface)->Release(deviceInterface);
            continue;
        }
        UInt32 locationID;
        kernReturn = (*deviceInterface)->GetLocationID(deviceInterface, &locationID);
        if (kernReturn != kIOReturnSuccess) {
            FDLog(@"failure GetLocationID: %08x", kernReturn);
        }
        
        FDUSBDevice *usbDevice = [[FDUSBDevice alloc] init];
        io_object_t notification;
        kernReturn = IOServiceAddInterestNotification(
                                                      _notificationPort,
                                                      service,
                                                      kIOGeneralInterest,
                                                      USBDeviceInterest,
                                                      (__bridge void *)usbDevice,
                                                      &notification
                                                      );
        if (kernReturn != kIOReturnSuccess) {
            FDLog(@"failure IOServiceAddInterestNotification: %08x", kernReturn);
        }
        usbDevice.usbMonitor = self;
        usbDevice.deviceInterface = deviceInterface;
        usbDevice.notification = notification;
        [_usbDevices addObject:usbDevice];
        [_delegate usbMonitor:self usbDeviceAdded:usbDevice];
    }
}

static
void USBDevicesAdded(void *refcon, io_iterator_t iterator)
{
    FDUSBMonitor *usbMonitor = (__bridge FDUSBMonitor *)refcon;
    [usbMonitor USBDevicesAdded:iterator];
}

- (void)USBStart
{
    mach_port_t masterPort;
    kern_return_t kernReturn = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure IOMasterPort: %08x", kernReturn);
    }
    _notificationPort = IONotificationPortCreate(masterPort);
    
    CFRunLoopSourceRef runLoopSourceRef = IONotificationPortGetRunLoopSource(_notificationPort);
    CFRunLoopRef runLoopRef = CFRunLoopGetCurrent();
    CFRunLoopAddSource(runLoopRef, runLoopSourceRef, kCFRunLoopDefaultMode);
    
    CFDictionaryRef matchingDictionary = IOServiceMatching(kIOUSBDeviceClassName);
    io_iterator_t gRawAddedIter;
    kernReturn = IOServiceAddMatchingNotification(
                                                  _notificationPort,
                                                  kIOFirstMatchNotification,
                                                  matchingDictionary,
                                                  USBDevicesAdded, (__bridge void *)self,
                                                  &gRawAddedIter
                                                  );
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure IOServiceAddMatchingNotification: %08x", kernReturn);
    }
    [self USBDevicesAdded:gRawAddedIter];
}

- (void)USBRun:(id)argument
{
    [self USBStart];
    
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
    while (true) {
        [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

- (void)start
{
    _thread = [[NSThread alloc] initWithTarget:self selector:@selector(USBRun:) object:nil];
    [_thread start];
}

@end