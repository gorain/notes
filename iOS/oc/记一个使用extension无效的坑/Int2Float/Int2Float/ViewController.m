//
//  ViewController.m
//  Int2Float
//
//  Created by 故园 on 2017/4/17.
//  Copyright © 2017年 故园. All rights reserved.
//

#import "ViewController.h"
#import "UIView+B.h"
#import "Person.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    [btn setBackgroundColor:[UIColor blackColor]];
    
    [self.view addSubview:btn];
    
    btn.height = 50;
    
    Person* person = [[Person alloc] init];
    [person read:@"abcd"];
}

- (void) forceTransferAndPointer {
    double d = 50;
    float f = (float)d;
    float f2 = *((float*)&d);
    NSLog(@"%f, %f", f, f2);
    // 50.000000, 0.000000
}

- (void) floatDivide {
    float left = 11.23456789;
    left /= 10;
    float right = 1.123456789;
    NSLog(@"%f, %f", left, right);
    if (left == right) {
        NSLog(@"these two are equal");
    } else {
        NSLog(@"these two are not equal");
    }
    // 1.123457, 1.123457
    // these two are not equal
}

- (void) floatSubtract {
    float left = 1.012345678;
    left -= 1.012345678;
    NSLog(@"%f", left);
    if (left == 0) {
        NSLog(@"It is zero");
    } else {
        NSLog(@"It is not zero");
    }
    // -0.000000 // 注意这里都有 -0 了
    // It is not zero
}

@end

