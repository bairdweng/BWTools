//
//  BWMemoryCache.h
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BWMemoryCache : NSObject
#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================

//缓存名称，默认为nil
@property (nullable, copy) NSString *name;

//缓存总数量
@property (readonly) NSUInteger totalCount;

//缓存总开销
@property (readonly) NSUInteger totalCost;



#pragma mark - Limit
//数量上限，默认为NSUIntegerMax，也就是无上限
@property NSUInteger countLimit;

//开销上限，默认为NSUIntegerMax，也就是无上限
@property NSUInteger costLimit;

//缓存时间上限，默认为DBL_MAX，也就是无上限
@property NSTimeInterval ageLimit;

//清理超出上限之外的缓存的操作间隔时间，默认为5s
@property NSTimeInterval autoTrimInterval;

//收到内存警告时是否清理所有缓存，默认为YES
@property BOOL shouldRemoveAllObjectsOnMemoryWarning;

//app进入后台是是否清理所有缓存，默认为YES
@property BOOL shouldRemoveAllObjectsWhenEnteringBackground;

//收到内存警告的回调block
@property (nullable, copy) void(^didReceiveMemoryWarningBlock)(BWMemoryCache *cache);

//进入后台的回调block
@property (nullable, copy) void(^didEnterBackgroundBlock)(BWMemoryCache *cache);

//缓存清理是否在后台进行，默认为NO
@property BOOL releaseOnMainThread;

//缓存清理是否异步执行，默认为YES
@property BOOL releaseAsynchronously;


#pragma mark - Access Methods

//是否包含某个缓存
- (BOOL)containsObjectForKey:(id)key;

//获取缓存对象
- (nullable id)objectForKey:(id)key;

//写入缓存对象
- (void)setObject:(nullable id)object forKey:(id)key;

//写入缓存对象，并添加对应的开销
- (void)setObject:(nullable id)object forKey:(id)key withCost:(NSUInteger)cost;

//移除某缓存
- (void)removeObjectForKey:(id)key;

//移除所有缓存
- (void)removeAllObjects;

#pragma mark - Trim

// =========== 缓存清理接口 ===========
//清理缓存到指定个数
- (void)trimToCount:(NSUInteger)count;

//清理缓存到指定开销
- (void)trimToCost:(NSUInteger)cost;

//清理缓存时间小于指定时间的缓存
- (void)trimToAge:(NSTimeInterval)age;

@end

NS_ASSUME_NONNULL_END
