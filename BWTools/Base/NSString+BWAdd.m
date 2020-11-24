//
//  NSString+BWAdd.m
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//

#import "NSString+BWAdd.h"
#import "NSData+YYAdd.h"

@implementation NSString (BWAdd)
- (NSString *)md5String {
    return [[self dataUsingEncoding:NSUTF8StringEncoding] md5String];
}

@end
