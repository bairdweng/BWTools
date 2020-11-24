//
//  BWMemoryCache.m
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//

#import "BWMemoryCache.h"
#import <UIKit/UIKit.h>
#import <pthread.h>


#if __has_include("BWDispatchQueuePool.h")
#import "BWDispatchQueuePool.h"
#endif

#ifdef BWDispatchQueuePool_h
static inline dispatch_queue_t BWMemoryCacheGetReleaseQueue() {
    return BWDispatchQueueGetForQOS(NSQualityOfServiceUtility);
}
#else
static inline dispatch_queue_t BWMemoryCacheGetReleaseQueue() {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
}
#endif

/**
 A node in linked map.
 Typically, you should not use this class directly.
 */
#pragma mark 知识点 双向链表的使用
@interface _BWLinkedMapNode : NSObject {
    @package
    __unsafe_unretained _BWLinkedMapNode *_prev; // retained by dic
    __unsafe_unretained _BWLinkedMapNode *_next; // retained by dic
    id _key;              //缓存key
    id _value;            //key对应值
    NSUInteger _cost;     //缓存开销
    NSTimeInterval _time; //访问时间
}
@end

@implementation _BWLinkedMapNode
@end


/**
 A linked map used by BWMemoryCache.
 It's not thread-safe and does not validate the parameters.
 
 Typically, you should not use this class directly.
 */
@interface _BWLinkedMap : NSObject {
    @package
    CFMutableDictionaryRef _dic;     // 用于存放节点
    NSUInteger _totalCost;           //总开销
    NSUInteger _totalCount;          //节点总数
    _BWLinkedMapNode *_head;            // 链表的头部结点
    _BWLinkedMapNode *_tail;         // 链表的尾部节点
    BOOL _releaseOnMainThread;             //是否在主线程释放，默认为NO
    BOOL _releaseAsynchronously;     //是否在子线程释放，默认为YES
}

/// Insert a node at head and update the total cost.
/// Node and node.key should not be nil.
- (void)insertNodeAtHead:(_BWLinkedMapNode *)node;

/// Bring a inner node to header.
/// Node should already inside the dic.
- (void)bringNodeToHead:(_BWLinkedMapNode *)node;

/// Remove a inner node and update the total cost.
/// Node should already inside the dic.
- (void)removeNode:(_BWLinkedMapNode *)node;

/// Remove tail node if exist.
- (_BWLinkedMapNode *)removeTailNode;

/// Remove all node in background queue.
- (void)removeAll;

@end

@implementation _BWLinkedMap

- (instancetype)init {
    self = [super init];
    _dic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    _releaseOnMainThread = NO;
    _releaseAsynchronously = YES;
    return self;
}

- (void)dealloc {
    CFRelease(_dic);
}

- (void)insertNodeAtHead:(_BWLinkedMapNode *)node {
    //设置该node的值
    CFDictionarySetValue(_dic, (__bridge const void *)(node->_key), (__bridge const void *)(node));
    _totalCost += node->_cost;
    _totalCount++;
    if (_head) {
        //如果链表内已经存在头节点，则将这个头节点赋给当前节点的尾指针（原第一个节点变成了现第二个节点）
        node->_next = _head;
        //将该节点赋给现第二个节点的头指针（此时_head指向的节点是先第二个节点）
        _head->_prev = node;
        //将该节点赋给链表的头结点指针（该节点变成了现第一个节点）
        _head = node;
    } else {
        //如果链表内没有头结点，说明是空链表。说明是第一次插入，则将链表的头尾节点都设置为当前节点
        _head = _tail = node;
    }
}
// 将某个节点移动到链表头部：
- (void)bringNodeToHead:(_BWLinkedMapNode *)node {
    if (_head == node) return;
    
    if (_tail == node) {
        //如果该节点是链表的尾部节点
        //1. 将该节点的头指针指向的节点变成链表的尾节点（将倒数第二个节点变成倒数第一个节点，即尾部节点）
        _tail = node->_prev;
        //2. 将新的尾部节点的尾部指针置空
        _tail->_next = nil;
    } else {
        //如果该节点是链表头部和尾部以外的节点（中间节点）
        //1. 将该node的头指针指向的节点赋给其尾指针指向的节点的头指针
        node->_next->_prev = node->_prev;
        //2. 将该node的尾指针指向的节点赋给其头指针指向的节点的尾指针
        node->_prev->_next = node->_next;
    }
    //将原头节点赋给该节点的尾指针（原第一个节点变成了现第二个节点）
    node->_next = _head;
    //将当前节点的头节点置空
    node->_prev = nil;
    //将现第二个节点的头结点指向当前节点（此时_head指向的节点是现第二个节点）
    _head->_prev = node;
    //将该节点设置为链表的头节点
    _head = node;
}

- (void)removeNode:(_BWLinkedMapNode *)node {
    //除去该node的键对应的值
    CFDictionaryRemoveValue(_dic, (__bridge const void *)(node->_key));
    
    //减去开销和总缓存数量
    _totalCost -= node->_cost;
    _totalCount--;
    
    //节点操作
    //1. 将该node的头指针指向的节点赋给其尾指针指向的节点的头指针
    if (node->_next) node->_next->_prev = node->_prev;
    
    //2. 将该node的尾指针指向的节点赋给其头指针指向的节点的尾指针
    if (node->_prev) node->_prev->_next = node->_next;
    
    //3. 如果该node就是链表的头结点，则将该node的尾部指针指向的节点赋给链表的头节点（第二变成了第一）
    if (_head == node) _head = node->_next;
    
    //4. 如果该node就是链表的尾节点，则将该node的头部指针指向的节点赋给链表的尾节点（倒数第二变成了倒数第一）
    if (_tail == node) _tail = node->_prev;
}

- (_BWLinkedMapNode *)removeTailNode {
    //如果不存在尾节点，则返回nil
    if (!_tail) return nil;
    
    _BWLinkedMapNode *tail = _tail;
    
    //移除尾部节点对应的值
    CFDictionaryRemoveValue(_dic, (__bridge const void *)(_tail->_key));
    
    //减少开销和总缓存数量
    _totalCost -= _tail->_cost;
    _totalCount--;
    
    if (_head == _tail) {
        //如果链表的头尾节点相同，说明链表只有一个节点。将其置空
        _head = _tail = nil;
        
    } else {
        
        //将链表的尾节指针指向的指针赋给链表的尾指针（倒数第二变成了倒数第一）
        _tail = _tail->_prev;
        //将新的尾节点的尾指针置空
        _tail->_next = nil;
    }
    return tail;
}

- (void)removeAll {
    _totalCost = 0;
    _totalCount = 0;
    _head = nil;
    _tail = nil;
    if (CFDictionaryGetCount(_dic) > 0) {
        CFMutableDictionaryRef holder = _dic;
        _dic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        
        if (_releaseAsynchronously) {
            dispatch_queue_t queue = _releaseOnMainThread ? dispatch_get_main_queue() : BWMemoryCacheGetReleaseQueue();
            dispatch_async(queue, ^{
                CFRelease(holder); // hold and release in specified queue
            });
        } else if (_releaseOnMainThread && !pthread_main_np()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CFRelease(holder); // hold and release in specified queue
            });
        } else {
            CFRelease(holder);
        }
    }
}

@end





#pragma mark pthread_mutex 互斥锁
/* 自旋锁 OSSpinLock 有风险已经别踢出局不再使用
 如果一个低优先级的线程获得锁并访问共享资源，这时一个高优先级的线程也尝试获得这个锁，它会处于 spin lock 的忙等状态从而占用大量 CPU。此时低优先级线程无法与高优先级线程争夺 CPU 时间，从而导致任务迟迟完不成、无法释放 lock。这并不只是理论上的问题，libobjc 已经遇到了很多次这个问题了，于是苹果的工程师停用了 OSSpinLock。
 自旋锁不会引起调用者睡眠，如果自旋锁已经被别的执行单元保持，调用者就一直循环在那里看是否该自旋锁的保持者已经释放了锁
 dispatch_semaphore是pthread_mutex_t的1.37倍左右
 互斥锁
 */
@implementation BWMemoryCache {
    pthread_mutex_t _lock;
    _BWLinkedMap *_lru;
    dispatch_queue_t _queue;
}


//开始定期清理
- (void)_trimRecursively {
    __weak typeof(self) _self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_autoTrimInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        __strong typeof(_self) self = _self;
        if (!self) return;
        //在后台进行清理操作
        [self _trimInBackground];
        //递归自己
        [self _trimRecursively];
    });
}

//清理所有不符合限制的缓存，顺序为：cost，count，age
- (void)_trimInBackground {
    dispatch_async(_queue, ^{
        [self _trimToCost:self->_costLimit];
        [self _trimToCount:self->_countLimit];
        [self _trimToAge:self->_ageLimit];
    });
}
//将内存缓存数量降至等于或小于传入的数量；如果传入的值为0，则删除全部内存缓存
- (void)_trimToCost:(NSUInteger)costLimit {
    BOOL finish = NO;
    pthread_mutex_lock(&_lock);
    if (costLimit == 0) {
        [_lru removeAll];
        finish = YES;
        //如果当前缓存的总数量已经小于或等于传入的数量，则直接返回YES，不进行清理
    } else if (_lru->_totalCost <= costLimit) {
        finish = YES;
    }
    pthread_mutex_unlock(&_lock);
    if (finish) return;
    
    NSMutableArray *holder = [NSMutableArray new];
    while (!finish) {
        //==0的时候说明在尝试加锁的时候，获取锁成功，从而可以进行操作；否则等待10秒（但是不知道为什么是10s而不是2s，5s，等等）回旋锁吗？
        if (pthread_mutex_trylock(&_lock) == 0) {
            if (_lru->_totalCost > costLimit) {
                _BWLinkedMapNode *node = [_lru removeTailNode];
                if (node) [holder addObject:node];
            } else {
                finish = YES;
            }
            pthread_mutex_unlock(&_lock);
        } else {
            usleep(10 * 1000); //10 ms
        }
    }
    if (holder.count) {
        dispatch_queue_t queue = _lru->_releaseOnMainThread ? dispatch_get_main_queue() : BWMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            [holder count]; // release in queue
        });
    }
}

- (void)_trimToCount:(NSUInteger)countLimit {
    BOOL finish = NO;
    pthread_mutex_lock(&_lock);
    if (countLimit == 0) {
        [_lru removeAll];
        finish = YES;
    } else if (_lru->_totalCount <= countLimit) {
        finish = YES;
    }
    pthread_mutex_unlock(&_lock);
    if (finish) return;
    
    NSMutableArray *holder = [NSMutableArray new];
    while (!finish) {
        if (pthread_mutex_trylock(&_lock) == 0) {
            if (_lru->_totalCount > countLimit) {
                _BWLinkedMapNode *node = [_lru removeTailNode];
                if (node) [holder addObject:node];
            } else {
                finish = YES;
            }
            pthread_mutex_unlock(&_lock);
        } else {
            usleep(10 * 1000); //10 ms
        }
    }
    if (holder.count) {
        dispatch_queue_t queue = _lru->_releaseOnMainThread ? dispatch_get_main_queue() : BWMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            [holder count]; // release in queue
        });
    }
}

- (void)_trimToAge:(NSTimeInterval)ageLimit {
    BOOL finish = NO;
    NSTimeInterval now = CACurrentMediaTime();
    pthread_mutex_lock(&_lock);
    if (ageLimit <= 0) {
        [_lru removeAll];
        finish = YES;
    } else if (!_lru->_tail || (now - _lru->_tail->_time) <= ageLimit) {
        finish = YES;
    }
    pthread_mutex_unlock(&_lock);
    if (finish) return;
    
    NSMutableArray *holder = [NSMutableArray new];
    while (!finish) {
        if (pthread_mutex_trylock(&_lock) == 0) {
            if (_lru->_tail && (now - _lru->_tail->_time) > ageLimit) {
                _BWLinkedMapNode *node = [_lru removeTailNode];
                if (node) [holder addObject:node];
            } else {
                finish = YES;
            }
            pthread_mutex_unlock(&_lock);
        } else {
            usleep(10 * 1000); //10 ms
        }
    }
    if (holder.count) {
        dispatch_queue_t queue = _lru->_releaseOnMainThread ? dispatch_get_main_queue() : BWMemoryCacheGetReleaseQueue();
        dispatch_async(queue, ^{
            [holder count]; // release in queue
        });
    }
}

- (void)_appDidReceiveMemoryWarningNotification {
    if (self.didReceiveMemoryWarningBlock) {
        self.didReceiveMemoryWarningBlock(self);
    }
    if (self.shouldRemoveAllObjectsOnMemoryWarning) {
        [self removeAllObjects];
    }
}

- (void)_appDidEnterBackgroundNotification {
    if (self.didEnterBackgroundBlock) {
        self.didEnterBackgroundBlock(self);
    }
    if (self.shouldRemoveAllObjectsWhenEnteringBackground) {
        [self removeAllObjects];
    }
}

#pragma mark - public

- (instancetype)init {
    self = super.init;
    pthread_mutex_init(&_lock, NULL);
    _lru = [_BWLinkedMap new];
    _queue = dispatch_queue_create("com.ibireme.cache.memory", DISPATCH_QUEUE_SERIAL);
    
    _countLimit = NSUIntegerMax;
    _costLimit = NSUIntegerMax;
    _ageLimit = DBL_MAX;
    _autoTrimInterval = 5.0;
    _shouldRemoveAllObjectsOnMemoryWarning = YES;
    _shouldRemoveAllObjectsWhenEnteringBackground = YES;
    
#pragma mark - 监听内存警告
    /*
     YYCache默认在收到内存警告和进入后台时，自动清除所有内存缓存。所以在YYMemoryCache的初始化方法里，我们可以看到这两个监听的动作：
     */
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appDidReceiveMemoryWarningNotification) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appDidEnterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [self _trimRecursively];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [_lru removeAll];
    pthread_mutex_destroy(&_lock);
}

- (NSUInteger)totalCount {
    pthread_mutex_lock(&_lock);
    NSUInteger count = _lru->_totalCount;
    pthread_mutex_unlock(&_lock);
    return count;
}
#pragma mark 互斥锁
/*
 在YYMemoryCache中，是使用互斥锁来保证线程安全的。 首先在YYMemoryCache的初始化方法中得到了互斥锁，并在它的所有接口里都加入了互斥锁来保证线程安全，包括setter，getter方法和缓存操作的实现。举几个例子：
 */
- (NSUInteger)totalCost {
    pthread_mutex_lock(&_lock);
    NSUInteger totalCost = _lru->_totalCost;
    pthread_mutex_unlock(&_lock);
    return totalCost;
}

- (BOOL)releaseOnMainThread {
    pthread_mutex_lock(&_lock);
    BOOL releaseOnMainThread = _lru->_releaseOnMainThread;
    pthread_mutex_unlock(&_lock);
    return releaseOnMainThread;
}

- (void)setReleaseOnMainThread:(BOOL)releaseOnMainThread {
    pthread_mutex_lock(&_lock);
    _lru->_releaseOnMainThread = releaseOnMainThread;
    pthread_mutex_unlock(&_lock);
}

- (BOOL)releaseAsynchronously {
    pthread_mutex_lock(&_lock);
    BOOL releaseAsynchronously = _lru->_releaseAsynchronously;
    pthread_mutex_unlock(&_lock);
    return releaseAsynchronously;
}

- (void)setReleaseAsynchronously:(BOOL)releaseAsynchronously {
    pthread_mutex_lock(&_lock);
    _lru->_releaseAsynchronously = releaseAsynchronously;
    pthread_mutex_unlock(&_lock);
}

- (BOOL)containsObjectForKey:(id)key {
    if (!key) return NO;
    pthread_mutex_lock(&_lock);
    BOOL contains = CFDictionaryContainsKey(_lru->_dic, (__bridge const void *)(key));
    pthread_mutex_unlock(&_lock);
    return contains;
}

- (id)objectForKey:(id)key {
    if (!key) return nil;
    pthread_mutex_lock(&_lock);
    _BWLinkedMapNode *node = CFDictionaryGetValue(_lru->_dic, (__bridge const void *)(key));
    if (node) {
        node->_time = CACurrentMediaTime();
        [_lru bringNodeToHead:node];
    }
    pthread_mutex_unlock(&_lock);
    return node ? node->_value : nil;
}

- (void)setObject:(id)object forKey:(id)key {
    [self setObject:object forKey:key withCost:0];
}

- (void)setObject:(id)object forKey:(id)key withCost:(NSUInteger)cost {
    if (!key) return;
    if (!object) {
        [self removeObjectForKey:key];
        return;
    }
    pthread_mutex_lock(&_lock);
    _BWLinkedMapNode *node = CFDictionaryGetValue(_lru->_dic, (__bridge const void *)(key));
    NSTimeInterval now = CACurrentMediaTime();
    if (node) {
        _lru->_totalCost -= node->_cost;
        _lru->_totalCost += cost;
        node->_cost = cost;
        node->_time = now;
        node->_value = object;
        [_lru bringNodeToHead:node];
    } else {
        node = [_BWLinkedMapNode new];
        node->_cost = cost;
        node->_time = now;
        node->_key = key;
        node->_value = object;
        [_lru insertNodeAtHead:node];
    }
    if (_lru->_totalCost > _costLimit) {
        dispatch_async(_queue, ^{
            [self trimToCost:self->_costLimit];
        });
    }
    if (_lru->_totalCount > _countLimit) {
        _BWLinkedMapNode *node = [_lru removeTailNode];
        if (_lru->_releaseAsynchronously) {
            dispatch_queue_t queue = _lru->_releaseOnMainThread ? dispatch_get_main_queue() : BWMemoryCacheGetReleaseQueue();
            dispatch_async(queue, ^{
                [node class]; //hold and release in queue
            });
        } else if (_lru->_releaseOnMainThread && !pthread_main_np()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [node class]; //hold and release in queue
            });
        }
    }
    pthread_mutex_unlock(&_lock);
}
#pragma mark -异步释放对象的技巧
/*
 为了异步将某个对象释放掉，可以通过在GCD的block里面给它发个消息来实现。这个技巧在该框架中很常见，举一个删除一个内存缓存的例子：
 
 首先将这个缓存的node类取出，然后异步将其释放掉
 为了释放掉这个node对象，在一个异步执行的（主队列或自定义队列里）block里给其发送了class这个消息。不需要纠结这个消息具体是什么，他的目的是为了避免编译错误，因为我们无法在block里面硬生生地将某个对象写进去。
 其实关于上面这一点我自己也有点拿不准，希望理解得比较透彻的同学能在下面留个言~ ^^
 
 */
- (void)removeObjectForKey:(id)key {
    if (!key) return;
    pthread_mutex_lock(&_lock);
    _BWLinkedMapNode *node = CFDictionaryGetValue(_lru->_dic, (__bridge const void *)(key));
    if (node) {
        [_lru removeNode:node];
        if (_lru->_releaseAsynchronously) {
            dispatch_queue_t queue = _lru->_releaseOnMainThread ? dispatch_get_main_queue() : BWMemoryCacheGetReleaseQueue();
            dispatch_async(queue, ^{
                [node class]; //hold and release in queue
            });
        } else if (_lru->_releaseOnMainThread && !pthread_main_np()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [node class]; //hold and release in queue
            });
        }
    }
    pthread_mutex_unlock(&_lock);
}

- (void)removeAllObjects {
    pthread_mutex_lock(&_lock);
    [_lru removeAll];
    pthread_mutex_unlock(&_lock);
}

- (void)trimToCount:(NSUInteger)count {
    if (count == 0) {
        [self removeAllObjects];
        return;
    }
    [self _trimToCount:count];
}

- (void)trimToCost:(NSUInteger)cost {
    [self _trimToCost:cost];
}

- (void)trimToAge:(NSTimeInterval)age {
    [self _trimToAge:age];
}

- (NSString *)description {
    if (_name) return [NSString stringWithFormat:@"<%@: %p> (%@)", self.class, self, _name];
    else return [NSString stringWithFormat:@"<%@: %p>", self.class, self];
}
@end
