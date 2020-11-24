//
//  BWLabel.m
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//

#import "BWLabel.h"
#import "BWAsyncLayer.h"
#import <CoreText/CoreText.h>
#import "BWTransaction.h"

@interface BWLabel() <BWAsyncLayerDelegate> {
    
    
    
    /// 定义一个结构体
    struct {
        unsigned int layoutNeedUpdate : 1;
        unsigned int showingHighlight : 1;
        
        unsigned int trackingTouch : 1;
        unsigned int swallowTouch : 1;
        unsigned int touchMoved : 1;
        
        unsigned int hasTapAction : 1;
        unsigned int hasLongPressAction : 1;
        
        unsigned int contentsNeedFade : 1;
    } _state;
}

@end


@implementation BWLabel


- (instancetype)init
{
    self = [super init];
    if (self) {
        [self _initLabel];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _initLabel];
    }
    return self;
}
- (void)setText:(NSString *)text {
    _text = text;
    // why?
    [[BWTransaction transactionWithTarget:self selector:@selector(contentsNeedUpdated)]commit];
}
- (void)contentsNeedUpdated {
    // do update
    [self.layer setNeedsDisplay];
}
- (void)_initLabel {
    ((BWAsyncLayer *)self.layer).displaysAsynchronously = YES;
    ((BWAsyncLayer *)self.layer).delegate = self;
    self.layer.contentsScale = [UIScreen mainScreen].scale;
    self.contentMode = UIViewContentModeRedraw;
    self.isAccessibilityElement = YES;
}

+ (Class)layerClass {
    return [BWAsyncLayer class];
}
- (nonnull BWAsyncLayerDisplayTask *)newAsyncDisplayTask {

    __weak typeof(self)weakSelf = self;
    BWAsyncLayerDisplayTask *task = [BWAsyncLayerDisplayTask new];
    task.willDisplay = ^(CALayer * _Nonnull layer) {
        [layer removeAnimationForKey:@"contents"];
    };
    task.display = ^(CGContextRef  _Nonnull context, CGSize size, BOOL (^ _Nonnull isCancelled)(void)) {
        if (isCancelled()){
            return;
        }
        [weakSelf drawInContext:context withSize:size];
    };
    task.didDisplay = ^(CALayer * _Nonnull layer, BOOL finished) {
        
    };
    
    return  task;
}
// CoreText线程安全，可以在异步操作
- (void)drawInContext:(CGContextRef)context withSize:(CGSize)size {
    //设置context的ctm，用于适应core text的坐标体系
    CGContextSaveGState(context);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, size.width, size.height));
    NSMutableAttributedString *attri = [[NSMutableAttributedString alloc]initWithString:_text];
    [attri addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:10] range:NSMakeRange(0, _text.length)];
    
    CTFramesetterRef ctFramesetting = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attri);
    CTFrameRef ctFrame = CTFramesetterCreateFrame(ctFramesetting, CFRangeMake(0, attri.length), path, NULL);
    //6.在CTFrame中绘制文本关联上下文
    CTFrameDraw(ctFrame, context);
    //7.释放变量
    CFRelease(path);
    CFRelease(ctFramesetting);
    CFRelease(ctFrame);

}

@end
