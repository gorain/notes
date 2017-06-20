//
//  UIView+B.m
//  Int2Float
//
//  Created by 故园 on 2017/4/17.
//  Copyright © 2017年 故园. All rights reserved.
//

#import "UIView+B.h"

@implementation UIView (B)

- (void)setHeight:(float)height {
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, height);
}

- (float)height {
    return self.frame.size.height;
}

@end
