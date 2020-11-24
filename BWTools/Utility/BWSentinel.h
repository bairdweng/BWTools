//
//  BWSentinel.h
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
// 线程安全的计数器，用于判断异步绘制任务是否被取消

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BWSentinel : NSObject
@property (readonly) int32_t value;
- (int32_t)increase;

@end

NS_ASSUME_NONNULL_END
