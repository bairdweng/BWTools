//
//  BWTransaction.h
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//  将BWAsyncLayer委托的绘制任务注册Runloop调用，在RunLoop空闲时执行

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BWTransaction : NSObject

+ (BWTransaction *)transactionWithTarget:(id)target selector:(SEL)selector;
- (void)commit;
@end

NS_ASSUME_NONNULL_END
