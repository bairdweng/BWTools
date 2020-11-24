//
//  BWSentinel.m
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//

#import "BWSentinel.h"
#import <libkern/OSAtomic.h>

@implementation BWSentinel  {
    int32_t _value;
}
- (int32_t)value {
    return _value;
}

- (int32_t)increase {
    return OSAtomicIncrement32(&_value);
}

@end
