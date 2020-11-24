//
//  BWTransaction.m
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//

#import "BWTransaction.h"



@interface BWTransaction()
@property (nonatomic, strong) id target;
@property (nonatomic, assign) SEL selector;
@end
static NSMutableSet *transactionSet = nil;


static void YYRunLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    if (transactionSet.count == 0) return;
    NSSet *currentSet = transactionSet;
    // 重新清空了transaction
    transactionSet = [NSMutableSet new];
    [currentSet enumerateObjectsUsingBlock:^(BWTransaction *transaction, BOOL *stop) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [transaction.target performSelector:transaction.selector];
#pragma clang diagnostic pop
    }];
}
static void BWTransactionSetup() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        transactionSet = [NSMutableSet new];
        CFRunLoopRef runloop = CFRunLoopGetMain();
        CFRunLoopObserverRef observer;
        /**
                 创建一个RunLoop的观察者
                 allocator：该参数为对象内存分配器，一般使用默认的分配器kCFAllocatorDefault。或者nil
                 activities：该参数配置观察者监听Run Loop的哪种运行状态，这里我们监听beforeWaiting和exit状态
                 repeats：CFRunLoopObserver是否循环调用。
                 order：CFRunLoopObserver的优先级，当在Runloop同一运行阶段中有多个CFRunLoopObserver时，根据这个来先后调用CFRunLoopObserver，0为最高优先级别。正常情况下使用0。
                 callout：观察者的回调函数，在Core Foundation框架中用CFRunLoopObserverCallBack重定义了回调函数的闭包。
                 context：观察者的上下文。 (类似与KVO传递的context，可以传递信息，)因为这个函数创建ovserver的时候需要传递进一个函数指针，而这个函数指针可能用在n多个oberver 可以当做区分是哪个observer的状机态。（下面的通过block创建的observer一般是一对一的，一般也不需要Context，），还有一个例子类似与NSNOtificationCenter的 SEL和 Block方式
                 */
            observer = CFRunLoopObserverCreate(CFAllocatorGetDefault(),
                                           kCFRunLoopBeforeWaiting | kCFRunLoopExit,
                                           true,      // repeat
                                           0xFFFFFF,  // after CATransaction(2000000)
                                           YYRunLoopObserverCallBack, NULL);
        CFRunLoopAddObserver(runloop, observer, kCFRunLoopCommonModes);
        CFRelease(observer);
    });
}


@implementation BWTransaction
+ (BWTransaction *)transactionWithTarget:(id)target selector:(SEL)selector{
    if (!target || !selector) return nil;
    BWTransaction *t = [BWTransaction new];
    t.target = target;
    t.selector = selector;
    return t;
}

- (void)commit {
    if (!_target || !_selector) return;
    BWTransactionSetup();
    [transactionSet addObject:self];
}

- (NSUInteger)hash {
    long v1 = (long)((void *)_selector);
    long v2 = (long)_target;
    return v1 ^ v2;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isMemberOfClass:self.class]) return NO;
    BWTransaction *other = object;
    return other.selector == _selector && other.target == _target;
}
@end
