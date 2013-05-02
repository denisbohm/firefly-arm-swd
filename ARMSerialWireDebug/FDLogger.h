//
//  FDLogger.h
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FDLoggerConsumer <NSObject>

- (void)logFile:(char *)file line:(NSUInteger)line class:(NSString *)class method:(NSString *)method message:(NSString *)message;

@end

@interface FDLogger : NSObject

+ (void)logFile:(char *)file line:(NSUInteger)line class:(NSString *)class method:(NSString *)method format:(NSString *)format, ...;

+ (void)setConsumer:(id<FDLoggerConsumer>)consumer;

@end

#define FDLog(f, ...) [FDLogger logFile:__FILE__ line:__LINE__ class:[self className] method:NSStringFromSelector(_cmd) format:f, ##__VA_ARGS__]