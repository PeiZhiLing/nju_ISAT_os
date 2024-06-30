#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>

int main() {
    int pipe_fd[2];
    pid_t cat_pid, sort_pid;

    // 创建管道
    if (pipe(pipe_fd) == -1) {
        exit(EXIT_FAILURE);
    }

    // 创建第一个子进程来执行 "cat"
    if ((cat_pid = fork()) == -1) {
        exit(EXIT_FAILURE);
    }

    if (cat_pid == 0) {
        // 子进程1 (cat)
        // 关闭管道的输出，因为fork出的子进程会也拥有两个⽂件描述符指向同⼀管道，管道只支持单向通信，所以两个进程只能使用一个管道口，必须关闭另一个
        close(pipe_fd[0]);
        close(STDOUT_FILENO);
        // 重定向标准输出到管道的输入端
        dup(pipe_fd[1]);

        // 关闭多余的文件描述符
        close(pipe_fd[1]);

        // 执行 "cat test1.txt test2.txt"
        execlp("cat", "cat", "test1.txt", "test2.txt", (char *)NULL);

    
    }

    // 创建第二个子进程来执行 "sort"
    if ((sort_pid = fork()) == -1) {
       
        exit(EXIT_FAILURE);
    }

    if (sort_pid == 0) {
        // 子进程2 (sort)
        // 关闭管道的写入端
        close(pipe_fd[1]);
        
        close(STDIN_FILENO);

        // 重定向标准输入到管道的读取端
        dup(pipe_fd[0]);

        // 关闭多余的文件描述符
        close(pipe_fd[0]);

        // 执行 "sort"
        execlp("sort", "sort", (char *)NULL);

    }

    // 父进程
    // 关闭管道的两端
    close(pipe_fd[0]);
    close(pipe_fd[1]);

    // 等待所有子进程结束
    waitpid(cat_pid, NULL, 0);
    waitpid(sort_pid, NULL, 0);

    return 0;
}
