#include "rw_lock.h"

// 初始化读写锁
void rw_lock_init(rw_lock *lock) {
    lock->rc = 0;
    sem_init(&lock->wr_mutex, 0, 1);
    sem_init(&lock->mutex, 0, 1);
}

// 读操作
void rw_lock_read_lock(rw_lock *lock) {
    sem_wait(&lock->mutex);
    lock->rc++;
    if (lock->rc == 1) {
        sem_wait(&lock->wr_mutex);
    }
    sem_post(&lock->mutex);
}

// 读操作完成
void rw_lock_read_unlock(rw_lock *lock) {
    sem_wait(&lock->mutex);
    lock->rc--;
    if (lock->rc == 0) {
        sem_post(&lock->wr_mutex);
    }
    sem_post(&lock->mutex);
}

// 写操作
void rw_lock_write_lock(rw_lock *lock) {
    sem_wait(&lock->wr_mutex);
}

// 写操作完成
void rw_lock_write_unlock(rw_lock *lock) {
    sem_post(&lock->wr_mutex);
}
