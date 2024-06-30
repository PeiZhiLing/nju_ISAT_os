#ifndef RW_LOCK_H
#define RW_LOCK_H

#include <semaphore.h>
#include <pthread.h>

// 定义测试方法枚举
typedef enum {
    READ_FIRST,
    WRITE_FIRST,
    ALTERNATE,
    RANDOM
} TestMethod;

// 定义锁类型枚举
typedef enum {
    RW_LOCK,
    PTHREAD_RWLOCK
} LockType;

// 定义读写锁结构体
typedef struct {
    int rc;          // 读者数量
    sem_t wr_mutex;  // 写者互斥信号量
    sem_t mutex;     // 读者数量互斥信号量
} rw_lock;

// 初始化读写锁
void rw_lock_init(rw_lock *lock);

// 读操作
void rw_lock_read_lock(rw_lock *lock);

// 读操作完成
void rw_lock_read_unlock(rw_lock *lock);

// 写操作
void rw_lock_write_lock(rw_lock *lock);

// 写操作完成
void rw_lock_write_unlock(rw_lock *lock);

#endif /* RW_LOCK_H */
