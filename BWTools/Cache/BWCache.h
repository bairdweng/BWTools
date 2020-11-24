//
//  BWCache.h
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//



/*
 BWMemoryCache 使用了 pthread_mutex 线程锁（互斥锁）来确保线程安全
 BWDiskCache 则选择了更适合它的 dispatch_semaphore。
 */

#import <Foundation/Foundation.h>
@class BWMemoryCache, BWDiskCache;

NS_ASSUME_NONNULL_BEGIN

@interface BWCache : NSObject
@property (copy, readonly) NSString *name;
@property (strong, readonly) BWMemoryCache *memoryCache;
@property (strong, readonly) BWDiskCache *diskCache;

- (nullable instancetype)initWithName:(NSString *)name;

#pragma mark 废弃标记
/*
 而剩下的四个可以使用的初始化方法中，有一个是指定初始化方法，被作者用NS_DESIGNATED_INITIALIZER标记了。
 */
- (nullable instancetype)initWithPath:(NSString *)path NS_DESIGNATED_INITIALIZER;

+ (nullable instancetype)cacheWithName:(NSString *)name;

+ (nullable instancetype)cacheWithPath:(NSString *)path;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;


- (BOOL)containsObjectForKey:(NSString *)key;

- (void)containsObjectForKey:(NSString *)key withBlock:(nullable void(^)(NSString *key, BOOL contains))block;

- (nullable id<NSCoding>)objectForKey:(NSString *)key;

- (void)objectForKey:(NSString *)key withBlock:(nullable void(^)(NSString *key, id<NSCoding> object))block;

- (void)setObject:(nullable id<NSCoding>)object forKey:(NSString *)key;

- (void)setObject:(nullable id<NSCoding>)object forKey:(NSString *)key withBlock:(nullable void(^)(void))block;

- (void)removeObjectForKey:(NSString *)key;

- (void)removeObjectForKey:(NSString *)key withBlock:(nullable void(^)(NSString *key))block;

- (void)removeAllObjects;

- (void)removeAllObjectsWithBlock:(void(^)(void))block;

- (void)removeAllObjectsWithProgressBlock:(nullable void(^)(int removedCount, int totalCount))progress
                                 endBlock:(nullable void(^)(BOOL error))end;
@end

NS_ASSUME_NONNULL_END
