//
//  UIApplication+BWAdd.h
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIApplication (BWAdd)
/// Returns YES in App Extension.
+ (BOOL)isAppExtension;

/// Same as sharedApplication, but returns nil in App Extension.
+ (nullable UIApplication *)sharedExtensionApplication;

@end

NS_ASSUME_NONNULL_END
