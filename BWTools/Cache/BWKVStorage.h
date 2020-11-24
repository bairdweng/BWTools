//
//  BWKVStorage.h
//  BWKit <https://github.com/ibireme/BWKit>
//
//  Created by ibireme on 15/4/22.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 BWKVStorageItem is used by `BWKVStorage` to store key-value pair and meta data.
 Typically, you should not use this class directly.
 */
@interface BWKVStorageItem : NSObject
@property (nonatomic, strong) NSString *key;                //键
@property (nonatomic, strong) NSData *value;                //值
@property (nullable, nonatomic, strong) NSString *filename; //文件名
@property (nonatomic) int size;                             //值的大小，单位是byte
@property (nonatomic) int modTime;                          //修改时间戳
@property (nonatomic) int accessTime;                       //最后访问的时间戳
@property (nullable, nonatomic, strong) NSData *extendedData; //extended data

@end

/**
 Storage type, indicated where the `BWKVStorageItem.value` stored.
 
 @discussion Typically, write data to sqlite is faster than extern file, but 
 reading performance is dependent on data size. In my test (on iPhone 6 64G), 
 read data from extern file is faster than from sqlite when the data is larger 
 than 20KB.
 
 * If you want to store large number of small datas (such as contacts cache), 
   use BWKVStorageTypeSQLite to get better performance.
 * If you want to store large files (such as image cache),
   use BWKVStorageTypeFile to get better performance.
 * You can use BWKVStorageTypeMixed and choice your storage type for each item.
 
 See <http://www.sqlite.org/intern-v-extern-blob.html> for more information.
 */
typedef NS_ENUM(NSUInteger, BWKVStorageType) {
    
    /// The `value` is stored as a file in file system.
    BWKVStorageTypeFile = 0,
    
    /// The `value` is stored in sqlite with blob type.
    BWKVStorageTypeSQLite = 1,
    
    /// The `value` is stored in file system or sqlite based on your choice.
    BWKVStorageTypeMixed = 2,
};



/**
 BWKVStorage is a key-value storage based on sqlite and file system.
 Typically, you should not use this class directly.
 
 @discussion The designated initializer for BWKVStorage is `initWithPath:type:`.
 After initialized, a directory is created based on the `path` to hold key-value data.
 Once initialized you should not read or write this directory without the instance.
 
 You may compile the latest version of sqlite and ignore the libsqlite3.dylib in
 iOS system to get 2x~4x speed up.
 
 @warning The instance of this class is *NOT* thread safe, you need to make sure 
 that there's only one thread to access the instance at the same time. If you really 
 need to process large amounts of data in multi-thread, you should split the data
 to multiple KVStorage instance (sharding).
 */
@interface BWKVStorage : NSObject

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================

@property (nonatomic, readonly) NSString *path;        ///< The path of this storage.
@property (nonatomic, readonly) BWKVStorageType type;  ///< The type of this storage.
@property (nonatomic) BOOL errorLogsEnabled;           ///< Set `YES` to enable error logs for debug.

#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;

/**
 The designated initializer. 
 
 @param path  Full path of a directory in which the storage will write data. If
    the directory is not exists, it will try to create one, otherwise it will 
    read the data in this directory.
 @param type  The storage type. After first initialized you should not change the 
    type of the specified path.
 @return  A new storage object, or nil if an error occurs.
 @warning Multiple instances with the same path will make the storage unstable.
 */
- (nullable instancetype)initWithPath:(NSString *)path type:(BWKVStorageType)type NS_DESIGNATED_INITIALIZER;


#pragma mark - Save Items
//写入某个item
- (BOOL)saveItem:(BWKVStorageItem *)item;

//写入某个键值对，值为NSData对象
- (BOOL)saveItemWithKey:(NSString *)key value:(NSData *)value;

//写入某个键值对，包括文件名以及data信息
- (BOOL)saveItemWithKey:(NSString *)key
                  value:(NSData *)value
               filename:(nullable NSString *)filename
           extendedData:(nullable NSData *)extendedData;

#pragma mark - Remove Items

//移除某个键的item
- (BOOL)removeItemForKey:(NSString *)key;

//移除多个键的item
- (BOOL)removeItemForKeys:(NSArray<NSString *> *)keys;

//移除大于参数size的item
- (BOOL)removeItemsLargerThanSize:(int)size;

//移除时间早于参数时间的item
- (BOOL)removeItemsEarlierThanTime:(int)time;

//移除item，使得缓存总容量小于参数size
- (BOOL)removeItemsToFitSize:(int)maxSize;

//移除item，使得缓存数量小于参数size
- (BOOL)removeItemsToFitCount:(int)maxCount;

//移除所有的item
- (BOOL)removeAllItems;

//移除所有的item，附带进度与结束block
- (void)removeAllItemsWithProgressBlock:(nullable void(^)(int removedCount, int totalCount))progress
                               endBlock:(nullable void(^)(BOOL error))end;


#pragma mark - Get Items
//读取参数key对应的item
- (nullable BWKVStorageItem *)getItemForKey:(NSString *)key;

//读取参数key对应的data
- (nullable NSData *)getItemValueForKey:(NSString *)key;

//读取参数数组对应的item数组
- (nullable NSArray<BWKVStorageItem *> *)getItemForKeys:(NSArray<NSString *> *)keys;

//读取参数数组对应的item字典
- (nullable NSDictionary<NSString *, NSData *> *)getItemValueForKeys:(NSArray<NSString *> *)keys;


#pragma mark - Get Storage Status
///=============================================================================
/// @name Get Storage Status
///=============================================================================

/**
 Whether an item exists for a specified key.
 
 @param key  A specified key.
 
 @return `YES` if there's an item exists for the key, `NO` if not exists or an error occurs.
 */
- (BOOL)itemExistsForKey:(NSString *)key;

/**
 Get total item count.
 @return Total item count, -1 when an error occurs.
 */
- (int)getItemsCount;

/**
 Get item value's total size in bytes.
 @return Total size in bytes, -1 when an error occurs.
 */
- (int)getItemsSize;

@end

NS_ASSUME_NONNULL_END
