//
//  Person+Extension.m
//  Int2Float
//
//  Created by 故园 on 2017/4/21.
//  Copyright © 2017年 故园. All rights reserved.
//

#import "Person+Extension.h"

@implementation Person (Extension)

- (void)read:(NSInteger)intValue {
    NSLog(@"intValue: %ld", (long)intValue);
    void* voids = (void *)intValue;
    NSString* str = (__bridge NSString *)(voids);
    NSLog(@"intValue by string: %@", str);
}

@end
