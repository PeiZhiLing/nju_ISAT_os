do:
	gcc -o main rw_lock.c PA7_main.c -pthread
#READ_FIRST：先创建所有读进程，再创建写进程
	./main READ_FIRST rw_lock
	./main READ_FIRST pthread_rwlock_t

#WRITE_FIRST：先创建所有写进程，再创建读进程
	./main WRITE_FIRST rw_lock
	./main WRITE_FIRST pthread_rwlock_t

#ALTERNATE：交替创建读写进程
	./main ALTERNATE rw_lock
	./main ALTERNATE pthread_rwlock_t
#RANDOM ：随机创建读写进程
	./main RANDOM rw_lock
	./main RANDOM pthread_rwlock_t





