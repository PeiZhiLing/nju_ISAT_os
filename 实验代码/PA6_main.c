#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>

#define TOTAL_POINTS 100000000 // 总采样点数

int total_points_inside_circle = 0;
pthread_mutex_t lock;

// 线程函数，执行蒙特卡洛随机采样
void *monte_carlo(void *arg) {
    int points_inside_circle = 0;
    unsigned int seed = time(NULL); // 使用当前时间作为种子
    int *thread_points = (int *)arg; // 每个线程的采样点数

    // 随机采样
    for (int i = 0; i < *thread_points; i++) {
        double x = (double)rand_r(&seed) / RAND_MAX; // 生成[0,1]之间的随机数
        double y = (double)rand_r(&seed) / RAND_MAX;
        double distance = x * x + y * y; // 计算点到原点的距离的平方
        if (distance <= 1) { // 若距离小于等于1，则点在圆内
            points_inside_circle++;
        }
    }

    // 更新总的圆内点数，需要加锁
    pthread_mutex_lock(&lock);
    total_points_inside_circle += points_inside_circle;
    pthread_mutex_unlock(&lock);

    pthread_exit(NULL); // 退出线程
}

int main(int argc, char *argv[]) {
    int num_threads = 1;

    // 解析命令行参数，获取线程数
    if (argc > 1) {
        num_threads = atoi(argv[1]);
    }

    // 检查线程数是否合法
    if (num_threads <= 0) {
        printf("Invalid number of threads. Exiting.\n");
        return 1;
    }
    printf("Numbers of thread: %d\n",num_threads);
    int points_per_thread = TOTAL_POINTS / num_threads; // 每个线程的采样点数

    pthread_t threads[num_threads];
    pthread_mutex_init(&lock, NULL); // 初始化互斥锁

    // 创建并启动多个线程进行蒙特卡洛采样
    for (int i = 0; i < num_threads; i++) {
        pthread_create(&threads[i], NULL, monte_carlo, &points_per_thread);
    }

    // 等待所有线程完成
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    pthread_mutex_destroy(&lock); // 销毁互斥锁

    // 根据采样结果计算π的估计值
    double pi_estimate = 4.0 * total_points_inside_circle / TOTAL_POINTS;
    printf("Estimated value of pi: %f\n", pi_estimate);

    return 0;
}
