//
//  ViewController.m
//  锁机制
//
//  Created by apple on 2018/3/8.
//  Copyright © 2018年 apple. All rights reserved.
//

#import "ViewController.h"

#import <pthread/pthread.h>
#import <libkern/OSAtomic.h>
#import <os/lock.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //[self synchronized];
    
    //[self dispatch_semaphore];
    
   // [self nslock];
    
    //[self nsRecursiveLock];
    
    //[self nscondition];
    
    //[self nsConditionLock];
    
    [self pthread_mutex];
    
    //[self osspinlock];
}

// synchronized
- (void)synchronized{
    NSObject *object = [[NSObject alloc] init];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // @synchronized(object) 使用object作为该锁的唯一标志，只有当标识相同时，才满足互斥，如果线程2的@synchronized(object)改为@synchronized(self),线程2就不会阻塞，@synchronized的优点就是我们不需要再代码中显示的创建锁对象，便可以实现锁的机制，但作为一种预防措施，@synchronized块会隐式的添加一个异常处理来保护代码。该处理会在异常抛出的时候自动释放互斥锁
        @synchronized(object){
            NSLog(@"需要线程同步的操作1 开始");
            sleep(3);
            NSLog(@"需要线程同步的操作1 结束");
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        @synchronized(object) {
            NSLog(@"需要线程同步的操作2");
        }
    });
}
// dispatch_semaphore -- 信号量
- (void)dispatch_semaphore{
    dispatch_semaphore_t signal = dispatch_semaphore_create(1);//传入值必须>=0,如果传入0则阻塞线程，并等待timeout,时间到之后会执行后面的代码，此时signal的值是 1
    dispatch_time_t overTime = dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // lock,会使得sinal的值 -1
        dispatch_semaphore_wait(signal, overTime);//阻塞当前线程（dispatch_apply也会阻塞线程）
        NSLog(@"需要线程同步的操作1 开始");
        sleep(3);
        NSLog(@"需要线程同步的操作1 结束");
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        dispatch_semaphore_wait(signal, overTime);
        NSLog(@"需要线程同步的操作2");
        dispatch_semaphore_signal(signal);// 解锁，会使得singal的值+1
    });
    
    // 所以dispatch_semaphore_wait函数的作用是，如果sinal的信号量值大于0,该函数所处的线程就继续执行下面的代码，并且将信号量的值-1，如果此时信号量的值为0.那么这个函数就阻塞当前线程，并等待timeOut,如果等待的过程信号量的值被dispatch_semaphore_signal(signal)，那么信号量就会+1，这个时候之前等待的dispatch_semaphore_wait所在线程获得了信号量，就能继续执行向下执行，并将信号量-1，如果在等待的过程中一直没有获取到信号量或者信号量一直为0，那么等到timeOut之后，所在的线程会自动执行下面的代码
}
// NSLock
- (void)nslock{
    
    /** 小结
     通过下面两段输出结果我们可以知道lock 线程会一直轮询锁是否解锁，一秒之后会挂起，假如锁在之后的某段时间内解锁了，那么线程会立马被唤醒
     而tryLock只会做一次检查是否能够枷锁 lockBeforeDate 是在未来的一段时间内多次的去检查是否加锁，如果超出来这段时间还没有加锁成功，那么之后也不会再去加锁
     注意tryLock不会阻塞当前线程，而lockBeforeDate因为要在指定的时间内尝试加锁，会阻塞线程
    */
    NSLock *lock = [[NSLock alloc] init];
    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [lock lock];
        NSLog(@"线程1");
        sleep(10);
        [lock unlock];
    });
    
    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [lock lock];
        NSLog(@"线程2");
        [lock unlock];
    });
    /** 打印结果
     2018-03-08 17:16:46.857827+0800 锁机制[2726:736315] 线程1
     2018-03-08 17:16:56.863175+0800 锁机制[2726:736324] 线程2
     */
    
    
    //线程1
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if([lock tryLock]){//尝试加锁，如果获取不到返回NO，不会阻塞线程
            NSLog(@"11锁可用");
            [lock unlock];
        }else{
            NSLog(@"11锁不可用");
        }
        if([lock lockBeforeDate:[NSDate date]]){
            NSLog(@"11需要线程同步的操作1 开始");
            sleep(10);
            NSLog(@"11需要线程同步的操作1 结束");
            [lock unlock];
        }else{
            NSLog(@"11线程超时");
        }
      
    });
    //线程2
     dispatch_async(dispatch_get_global_queue(0, 0), ^{
       //  sleep(1);
          NSLog(@"22检查是否会阻塞线程");
         if([lock tryLock]){//尝试加锁，如果获取不到返回NO，不会阻塞线程
             NSLog(@"22锁可用");
             [lock unlock];
         }else{
             NSLog(@"22锁不可用");
         }
          NSLog(@"22会阻塞线程吗");
         NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:3];
         if([lock lockBeforeDate:date]){//尝试在未来的3秒内获取锁，并阻塞线程，如果3秒内获取不到则返回NO ，不会阻塞线程
             NSLog(@"22没有超时，获得锁");
             [lock unlock];
         }else{
             NSLog(@"22超时，没有获得锁");
         }
     });
    //线程3
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        //  sleep(1);
        if([lock tryLock]){//尝试加锁，如果获取不到返回NO，不会阻塞线程
            NSLog(@"33锁可用");
            [lock unlock];
        }else{
            NSLog(@"33锁不可用");
        }
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:3];
         NSLog(@"33检查是否会阻塞线程");
        if([lock lockBeforeDate:date]){//尝试在未来的3秒内获取锁，并阻塞线程，如果3秒内获取不到则返回NO ，不会阻塞线程，且之后也不会自动再去获取锁
            NSLog(@"33没有超时，获得锁");
            [lock unlock];
        }else{
            NSLog(@"33超时，没有获得锁");
        }
        NSLog(@"33会阻塞线程吗");
    });
    /** 打印结果
     2018-03-08 16:49:26.856169+0800 锁机制[2480:661998] 11锁可用
     2018-03-08 16:49:26.856167+0800 锁机制[2480:661999] 22锁不可用
     2018-03-08 16:49:26.856168+0800 锁机制[2480:662000] 33锁不可用
     2018-03-08 16:49:26.856450+0800 锁机制[2480:661998] 11需要线程同步的操作1 开始
     2018-03-08 16:49:29.861521+0800 锁机制[2480:661999] 22超时，没有获得锁
     2018-03-08 16:49:29.861521+0800 锁机制[2480:662000] 33超时，没有获得锁
     2018-03-08 16:49:36.861705+0800 锁机制[2480:661998] 11需要线程同步的操作1 结束
     */
}

// NSRecursiveLock 实际上定义的是一个递归锁，这个锁可以被同一线程多次请求，而不会引起死锁，这主要是用在循环或递归操作中
// 他允许在同一个县城内多次枷锁，而不会造成死锁。递归会跟踪他被lock的次数，每次成功的lock都必须平衡调用unlock操作，只有这样才能达到一个平衡，锁最后才能被释放，以供其他线程使用
- (void)nsRecursiveLock{
    
    //NSLock *lock = [[NSLock alloc] init];
     NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        static void (^RecursiveMethod)(int);
        RecursiveMethod = ^(int value){
            [lock lock];
            if(value > 0){
                NSLog(@"value = %d", value);
                sleep(1);
                RecursiveMethod(value - 1);
            }
            [lock unlock];
        };
        RecursiveMethod(5);
    });
}

/**
 @interface NSCondition : NSObject <NSLocking> {
 @private
 void *_priv;
 }
 
 - (void)wait;
 - (BOOL)waitUntilDate:(NSDate *)limit;
 - (void)signal;
 - (void)broadcast;
 
 @property (nullable, copy) NSString *name NS_AVAILABLE(10_5, 2_0);
 
 @end
 */

/**
 NSCondition的对象实际上作为一个锁和一个线程检查器，锁上之后其他线程也能上锁，而之后可以根据条件决定是否继续运行线程，即线程是否要进入waiting状态，经测试，NSCondition不会像其他的锁一样，先轮询，而是直接进入waiting状态，当其他线程中的锁执行了signal或者broadcast方法时，线程被唤醒，继续运行之后的方法
 */
- (void)nscondition{
    NSCondition *lock = [[NSCondition alloc] init];
    NSMutableArray *array = [[NSMutableArray alloc] init];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [lock lock];
        while (!array.count) {
            [lock wait]; //阻塞线程 同waitUntilDate:(NSDate *)limit一样
        }
        [array removeAllObjects];
        NSLog(@"array removeAllObjects");
        [lock unlock];
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        sleep(2);
        [lock lock];
        [array addObject:@1];
        NSLog(@"array addObject:@1");
        [lock signal];// 发送一个信号，只能唤醒一个等待的线程，想唤醒多个就得多次调用这个方法，而broadcast可以唤醒所有在等待的线程，如果没有等待的线程，这两个方法都没有作用,如果不执行这个唤醒操作，那么等待的线程就不会被唤醒
        [lock unlock];
    });
}

// NSConditionLock条件锁
- (void)nsConditionLock{
    /** 小结
     NSConditionLock和NSLock类似，都遵循NSLocking协议，方法都类似,只是多了一个condition属性，以及每个操作都多了一个关于condition
     属性的方法，比如tryLock,tryLockWhenCondition,NSConditionLock可以称为条件锁。只有condition参数和初始化的condition值相等,lock
     才能进行加锁操作，而unLockWhenCondition并不是当condition符合条件才解锁，而是解锁之后，修改condition的值，
    */
    NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition:0];
    NSMutableArray *products = [NSMutableArray array];
    NSInteger HAS_DATA = 1;
    NSInteger NO_DATA = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [lock lockWhenCondition:NO_DATA];// 这里condition初始化值是0，所以值相等，加锁成功
        [products addObject:[[NSObject alloc] init]];
        NSLog(@"produce a product,总量:%zi",products.count);
        [lock unlockWithCondition:HAS_DATA];// 重新设置condition的值
    });
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"wait for product");
        [lock lockWhenCondition:HAS_DATA];
        [products removeObjectAtIndex:0];
        NSLog(@"custome a product");
        [lock unlockWithCondition:NO_DATA];
    });
}

// pthread_mutex -互斥锁
- (void)pthread_mutex{
    __block pthread_mutex_t theLock;//block修饰的对象可以在block更改也可以方式循环引用
    pthread_mutex_init(&theLock,NULL);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        pthread_mutex_lock(&theLock);
        // 临界区
        NSLog(@"需要线程同步的操作1 开始");
        sleep(1);
        NSLog(@"需要线程同步的操作1 结束");
        pthread_mutex_unlock(&theLock);
        if(pthread_mutex_destroy(&theLock) == 0){
            NSLog(@"11注销成功");
        }
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(10);
        pthread_mutex_lock(&theLock);// 如果当前锁已经被锁，那么就会阻塞线程
       // pthread_mutex_trylock(<#pthread_mutex_t * _Nonnull#>) 尝试加锁，如果当前mutex已经被锁，那么这个线程就直接return,不会阻塞线程
        //pthread_mutex_destroy(<#pthread_mutex_t * _Nonnull#>) 用于注销一个互斥锁。销毁一个互斥锁即意味着释放它所占用的资源，且要求锁当前处于开放状态（所谓的开放状态应该是指没有线程要用到这个锁了）。,返回0表示注销成功，否则返回错误码
        NSLog(@"需要线程同步的操作2");
        pthread_mutex_unlock(&theLock);
        
        
        NSLog(@"%d",pthread_mutex_destroy(&theLock));
        
    });
  /*  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // sleep(1);
        pthread_mutex_lock(&theLock);
        NSLog(@"需要线程同步的操作3");
        pthread_mutex_unlock(&theLock);
        
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // sleep(1);
        pthread_mutex_lock(&theLock);
        NSLog(@"需要线程同步的操作4");
        pthread_mutex_unlock(&theLock);
        
    });*/
}
// pthread_mutext_recursive  递归锁 ，和NSRecursiveLock类似
- (void)pthread_mutext_recursive{
    __block pthread_mutex_t theLock;
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr); // 初始化配置信息
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);// 设置类型
    pthread_mutex_init(&theLock, &attr);
    pthread_mutexattr_destroy(&attr);//使用完释放attr
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        static void (^MutextRecursiceMethod)(int);
        MutextRecursiceMethod = ^(int value){
            pthread_mutex_lock(&theLock);
            if(value > 0){
                NSLog(@"value = %d", value);
                sleep(1);
                MutextRecursiceMethod(value - 1);
            }
            
            pthread_mutex_unlock(&theLock);
        };
        MutextRecursiceMethod(5);
    });
}

/**
 OSSpinLock是一种自旋锁。也只有加锁，解锁， 尝试加锁三个方法，和NSLock不同的是NSLock请求加锁失败的话，会先轮询，但一秒过后便会使线程进入waiting状态，等待唤醒，而OSSpinLock会一直轮询（忙等机制），等待时会消耗大量CPU资源，不适用于较长时间的任务，如果临界区执行的时间很短，忙等的效率也许会更高
 */
- (void)osspinlock{
  /*  __block OSSpinLock theLock = OS_SPINLOCK_INIT;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&theLock);
        NSLog(@"需要线程同步的操作1 开始");
        sleep(3);
        NSLog(@"需要线程同步的操作1 结束");
        OSSpinLockUnlock(&theLock);
        
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&theLock);
        sleep(1);
        NSLog(@"需要线程同步的操作2");
        OSSpinLockUnlock(&theLock);
        
    });*/
   __block os_unfair_lock theLock = OS_UNFAIR_LOCK_INIT; // 替换了上面的OSSpinLock
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        os_unfair_lock_lock(&theLock);
        NSLog(@"需要线程同步的操作1 开始");
        sleep(3);
        NSLog(@"需要线程同步的操作1 结束");
        os_unfair_lock_unlock(&theLock);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        os_unfair_lock_lock(&theLock);
        sleep(1);
        NSLog(@"需要线程同步的操作2");
        os_unfair_lock_unlock(&theLock);
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
