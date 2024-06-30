#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include "rw_lock.h"


#define NUM_READERS 3
#define NUM_WRITERS 2
#define READ_TIME 1
#define WRITE_TIME 1

// 全局变量声明
rw_lock read_first_lock;   // 自定义读者优先读写锁
pthread_rwlock_t pthread_lock; // pthread读写锁
pthread_rwlockattr_t attr; //用于决定读写优先



// 自定义读者优先读写锁读线程函数
void *Read_first_reader(void *arg) {
    rw_lock_read_lock(&read_first_lock);
    printf("Read_first reader %ld is reading...\n", (long)arg);
    sleep(READ_TIME);
    rw_lock_read_unlock(&read_first_lock);
    printf("Read_first reader %ld finished reading.\n", (long)arg);
    return NULL;
}

// 自定义读者优先读写锁写线程函数
void *Read_first_writer(void *arg) {
    rw_lock_write_lock(&read_first_lock);
    printf("Read_first writer %ld is writing...\n", (long)arg);
    sleep(WRITE_TIME);
    rw_lock_write_unlock(&read_first_lock);
    printf("Read_first writer %ld finished writing.\n", (long)arg);
    return NULL;
}

// pthread读线程函数
void *pthread_reader(void *arg) {
    pthread_rwlock_rdlock(&pthread_lock);
    printf("Pthread reader %ld is reading...\n", (long)arg);
    sleep(READ_TIME);
    pthread_rwlock_unlock(&pthread_lock);
    printf("Pthread reader %ld finished reading.\n", (long)arg);
    return NULL;
}

// pthread写线程函数
void *pthread_writer(void *arg) {
    pthread_rwlock_wrlock(&pthread_lock);
    printf("Pthread writer %ld is writing...\n", (long)arg);
    sleep(WRITE_TIME);
    pthread_rwlock_unlock(&pthread_lock);
    printf("Pthread writer %ld finished writing.\n", (long)arg);
    return NULL;
}

// 创建读线程
void create_reader_threads(pthread_t *threads, long num_readers, LockType lock_type, long ld_start) {
    for (long i = ld_start; i < num_readers + ld_start; i++) {
        if (lock_type == RW_LOCK) {
            pthread_create(&threads[i - ld_start], NULL, Read_first_reader, (void *)i);
        } else if (lock_type == PTHREAD_RWLOCK) {
            pthread_create(&threads[i - ld_start], NULL, pthread_reader, (void *)i);
            //sleep(1);
        }
    }
}

// 创建写线程
void create_writer_threads(pthread_t *threads, long num_writers, LockType lock_type, long ld_start) {
    for (long i = ld_start; i < num_writers + ld_start; i++) {
        if (lock_type == RW_LOCK) {
            pthread_create(&threads[i - ld_start], NULL, Read_first_writer, (void *)i);
        } else if (lock_type == PTHREAD_RWLOCK) {
            pthread_create(&threads[i - ld_start], NULL, pthread_writer, (void *)i);
        }
    }
}

// 测试方法
void test(TestMethod method, LockType lock_type) {
    pthread_t threads[NUM_READERS + NUM_WRITERS];
    long i;
    long Id_readr = 0; //记录printf不同reader的id
    long Id_writer = 0;//记录printf不同writer的id

    if (lock_type == PTHREAD_RWLOCK) {
        pthread_rwlock_init(&pthread_lock, NULL); // 初始化pthread读写锁，默认读者优先
        //pthread_rwlock_init(&pthread_lock, &attr); // 初始化pthread读写锁，写者优先
    } else if (lock_type == RW_LOCK) {
        rw_lock_init(&read_first_lock); // 初始化自定义读者优先读写锁
    }

    switch (method) {
        case READ_FIRST: //先创建所有读进程，再创建写进程
            create_reader_threads(threads, NUM_READERS, lock_type, 0);
            usleep(100);
            create_writer_threads(&threads[NUM_READERS], NUM_WRITERS, lock_type, 0);
            break;
        case WRITE_FIRST: //先创建所有写进程，再创建读进程：write write read read read 
            create_writer_threads(threads, NUM_WRITERS, lock_type, 0);
            usleep(100);
            create_reader_threads(&threads[NUM_WRITERS], NUM_READERS, lock_type, 0);
            break;
        case ALTERNATE: //交替创建读写进程，按以下顺序：read，write，read，write...
            for (i = 0; i < NUM_READERS + NUM_WRITERS; i++) {
                if (i % 2 == 0) {
                    create_reader_threads(&threads[i], 1, lock_type, Id_readr);
                
                    Id_readr += 1;
                } else {
                    create_writer_threads(&threads[i], 1, lock_type, Id_writer);
                    Id_writer += 1;
                }

            }
            break;
        case RANDOM: //随机创建读写进程
            srand(time(NULL));
            for (i = 0; i < NUM_READERS + NUM_WRITERS; i++) {
                if (rand() % 2 == 0) {
                    create_reader_threads(&threads[i], 1, lock_type, Id_readr);
                    Id_readr += 1;
                } else {
                    create_writer_threads(&threads[i], 1, lock_type, Id_writer);
                    Id_writer += 1;
                }
                
            }
            break;

        default:
            printf("Invalid test method!\n");
            return;
    }

    // 等待线程结束
    for (i = 0; i < NUM_READERS + NUM_WRITERS; i++) {
        pthread_join(threads[i], NULL);
    }

    // 销毁锁
    if (lock_type == PTHREAD_RWLOCK) {
        pthread_rwlock_destroy(&pthread_lock);
    }
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s TestMethod(READ_FIRST or WRITE_FIRST or ALTERNATE or RANDOM) LockType(rw_lock or pthread_rwlock_t)\n", argv[0]);
        return 1;
    }

    printf("============================================================\n");
    printf("Testing method %s with lock type %s\n", argv[1], argv[2]);
    printf("============================================================\n");

    TestMethod test_method;
    LockType lock_type;

    pthread_rwlockattr_init(&attr);
    // 设置读写锁的属性，PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP 表示写优先
    //pthread_rwlockattr_setkind_np(&attr, PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP);


    if (strcmp(argv[1], "READ_FIRST") == 0) {
        test_method = READ_FIRST;
    } else if (strcmp(argv[1], "WRITE_FIRST") == 0) {
        test_method = WRITE_FIRST;
    } else if (strcmp(argv[1], "ALTERNATE") == 0) {
        test_method = ALTERNATE;
    } else if (strcmp(argv[1], "RANDOM") == 0) {
        test_method = RANDOM;
    } else {
        printf("Invalid test method!\n");
        return 1;
    }

    if (strcmp(argv[2], "rw_lock") == 0) {
        lock_type = RW_LOCK;
    } else if (strcmp(argv[2], "pthread_rwlock_t") == 0) {
        lock_type = PTHREAD_RWLOCK;
    } else {
        printf("Invalid lock type!\n");
        return 1;
    }

    test(test_method, lock_type);

    return 0;
}
