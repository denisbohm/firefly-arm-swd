//
//  FDLogger.m
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDLogger.h"

@implementation FDLogger

- (void)logFile:(char *)file line:(NSUInteger)line class:(NSString *)class method:(NSString *)method format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    if (_consumer) {
        [_consumer logFile:file line:line class:class method:method message:message];
    } else {
        NSLog(@"log: %s:%lu %@.%@ %@", file, line, class, method, message);
    }
}

@end
