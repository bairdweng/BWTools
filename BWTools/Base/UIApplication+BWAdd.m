//
//  UIApplication+BWAdd.m
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//

#import "UIApplication+BWAdd.h"

@implementation UIApplication (BWAdd)
+ (BOOL)isAppExtension {
    static BOOL isAppExtension = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"UIApplication");
        if(!cls || ![cls respondsToSelector:@selector(sharedApplication)]) isAppExtension = YES;
        if ([[[NSBundle mainBundle] bundlePath] hasSuffix:@".appex"]) isAppExtension = YES;
    });
    return isAppExtension;
}

+ (UIApplication *)sharedExtensionApplication {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    return [self isAppExtension] ? nil : [UIApplication performSelector:@selector(sharedApplication)];
#pragma clang diagnostic pop
}
@end
