//
//  BWAsyncLayer.h
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//  CALayer子类，用来异步渲染layer内容

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN


@class BWAsyncLayerDisplayTask;


@interface BWAsyncLayer : CALayer
/// 渲染代码是否在后台执行。默认是肯定的。
@property BOOL displaysAsynchronously;

@end


/// 定义一个协议。
@protocol BWAsyncLayerDelegate <NSObject>
@required

/// 协议的方法
- (BWAsyncLayerDisplayTask *)newAsyncDisplayTask;
@end


/**
   用来呈现后台队列中的内容的显示任务。
 */
@interface BWAsyncLayerDisplayTask : NSObject

/**
 这个块将在异步绘制开始之前被调用。
 它将在主线程上被调用。

 块参数层:层。
 */
@property (nullable, nonatomic, copy) void (^willDisplay)(CALayer *layer);

/**
 这个块被调用来绘制层的内容。

 此块可以在主线程或后台线程上调用，
 所以is应该是线程安全的。

 块参数上下文:层创建的新位图内容。
 块参数大小:内容大小(通常与层的绑定大小相同)。
 块参数isCancelled:如果这个块返回' YES '，该方法应该取消
 拉拔过程并尽快返回。
 */
@property (nullable, nonatomic, copy) void (^display)(CGContextRef context, CGSize size, BOOL(^isCancelled)(void));

/**
 这个块将在异步绘制完成后被调用。
 它将在主线程上被调用。

 块参数层:层。
 block参数结束:如果取消绘制过程，它是' NO '，否则它是' YES ';
 */
@property (nullable, nonatomic, copy) void (^didDisplay)(CALayer *layer, BOOL finished);

@end


NS_ASSUME_NONNULL_END
