;设置代码段的起始位置
BITS 16
SECTION MBR vstart=0x7c00
_start:
    ;清屏
    mov ax, 0600h
    mov bx, 0700h
    mov cx, 0
    mov dx, 184fh
    int 10h

    ;初始化栈：给应用程序app用的
    xor ax,ax
    mov sp,0x8000
    mov ss,ax
   
    ;初始化段地址
    mov es,ax
    mov ds,ax
    ;写入中断向量表
        ;时钟中断处理：08h
    mov word [32],clock_interrupt_handler
    mov word [32+2],0

        ;write：80h
    mov word [0x80*4],write_function
    mov word [0x80*4+2],0

        ;sleep：81h
    mov word [0x81*4],sleep_function
    mov word [0x81*4+2],0

        ;fork：82h
    mov word [0x82*4],fork_function
    mov word [0x82*4+2],0

    ;设置时钟频率
    ; 设置8253的控制字，选择通道0并设置为方式3
    mov dx, 0x43
    mov al, 0x36
    out dx, al

    ;设置计数初值为23863
    mov dx, 0x40
    mov ax, 23863
    out dx, al
    mov al, ah
    out dx, al

    ;加载app
    mov bx,0x8000       
    mov ah, 2       ; BIOS读取扇区功能号
    mov al, 1       ; 读取扇区的数量
    mov ch, 0       ; 柱面号清零
    mov cl, 2       ; 从第二个扇区开始
    mov dh, 0       ; 磁头号清零
    mov dl, 0x80       ; 使用默认的驱动器号

    int 0x13        ; 调用BIOS中断13h读取磁盘扇区
   
    ;按严谨的逻辑需要这两个指令，但是为了节省代码字节，在数据段初始化
    ;mov word [state_father],2 ;将app父进程设为运行态
    ;mov word [state_current],0 ;标志当前进程为app father进程

    sti
    pushf
    push word 0 ;cs
    push word 0x8000 ;ip
    iret  ;从内核到应用程序执行
    

;int 82h
fork_function:
    ;复制app从0x0000:0x8000到0x2000:0x8000，连带着栈的内容,代码段，数据段一起复制，这里有个易错点，栈是从高位往低位存储的，而栈底初始化为0x8000，所以栈保存的内容在0x8000之上，需要从当前sp指向的地址开始复制，这样确保将栈的内容一同复制了
     xor ax, ax      

    ;复制到es:di
    mov word es,[CHILD_ES]
    mov di,sp  ;es:di=0x2000:sp

    ;从sp栈顶开始复制
    mov si, sp  ;ds:si=00:sp
    mov cx, 0x250  ;592个字节
    cld
    rep movsb
;DS:SI
;ES:DI
;CX 复制字节数
;DF=0 （cld）
;rep movsb将CX个字节从DS:SI复制到ES:DI处，SI和DI会自动+2

    mov es,ax ;复原es段地址为0x0000
    mov [CHILD_STACK],sp ;保存子进程栈指针
    
    ;修改fork的栈内容
    ;注意，因为我们要修改的是子进程的栈的内容，子进程的栈在0x2000段，所以需要将数据段地址寄存器ds修改为子进程所在段
    mov word ds,[CHILD_ES]
    mov di,sp
    mov [di+6],ax ;修改栈中返回值ax
    mov ds,ax ;复原

    iret ;此处仍旧是返回app的父进程

 ;int 80h
write_function:
    ;注意：因为有可能从子进程进来，此时的ds=0x2000，但是我们所有变量都在0x0000段，所以需要[es:counter3]的格式取数据，因为我们除了在fork使用过es，其余时间es都是0x0000不变
    ;bx=字符串绝对地址，cx = 串长度
    mov bp,bx ; es:bp = 串地址
    mov ax,01301h ; ah = 13, al = 01h
    mov bx,000ch ;页号为 0(bh = 0) 黑底红字(bl = 0Ch,高亮)
    mov dh,[es:counter3]   ;显示的行号
    mov dl,39  ;显示的列号
    int 10h
    inc byte [es:counter3]
    cmp dh,24  ;当到达页面最后一行，那么返回第一行输出
    jz zero
    iret
zero:
    mov word [es:counter3],0
    iret


; int 81h
sleep_function:
    ; dx里装着秒数
    imul dx, 50 ; 将ax和cx的值相乘，结果存入dx
    cmp word [es:state_father],2
    jz father_sleep ;父进程处于运行态，说明从父进程来的
;如果不是父进程来的就是子进程来的，顺序执行下面的指令
child_sleep:
    ;一旦子进程需要睡眠，就可以把数据段地址ds和栈段地址ss恢复为0
    xor ax,ax
    mov ds,ax
    mov ss,ax
    ;dx中是倒计时的数值，将秒的值存入子进程对应的计数器counter2
    mov [counter2], dx 
    ;检测父进程是否处于就绪态
    cmp word [state_father],1
    ;在跳转前修改子进程状态为睡眠态，之所以不在一开始就修改，是为了避免时钟中断处理的干扰（因为只要父进程状态仍处于运行态就时钟中断处理就不会进行任何处理）
    mov word [state_child],0
    jz child_to_father ;处于就绪态则调度父进程
    ;否则调idle
    mov [CHILD_STACK],sp ;每次调度前都记得保存当前进程的栈指针
    jmp to_idle
;从父进程发出的sleep
father_sleep:
    ;dx中是倒计时的数值，将秒的值存入counter
    mov [counter1], dx 
    ;检测子进程是否处于就绪态
    cmp word [state_child],1
     ;在跳转前修改父进程状态为睡眠态
    mov word [state_father],0
    jz  father_to_child ;处于就绪态则调度子进程
    ;否则调idle进程
    mov [FATHER_STACK],sp ;每次调度前都记得保存当前进程的栈指针
    jmp to_idle
    
;调度idle进程：这是个通用的指令段，既可以从父进程进行调度切换，也可以从子进程进行调度切换，节约字节
to_idle:
    mov sp,[IDLE_STACK] ;切换栈
    sti
    pushf ;保存标志寄存器状态
    push word 0 ;cs
    push word idle ;ip
    iret ;使用iret从内核到进程函数idle


;sleep时间从子进程调度切换至父进程   
child_to_father:
    mov word [state_father],2 ;父进程切换至运行态
    ;保存栈指针，切换栈指针
    mov [CHILD_STACK],sp
    mov sp,[FATHER_STACK]
    iret
;sleep时间从父进程调度切换至子进程
father_to_child:
    mov word [state_child],2 ;子进程切换至运行态
    ;保存栈指针，切换栈指针
    mov [FATHER_STACK],sp
    mov sp,[CHILD_STACK]

    ;在进入子进程前需要把ss和ds修改为子进程所在段（以便能够正确取得全局变量）
    ;注意：ss一定要放在ds前，因为[CHILD_ES]是在0x0000段，如果先修改了ds数据寄存器会导致出错；或者可以使用mov ss,[es:CHILD_ES]
    mov ss,[CHILD_ES]
    mov ds,[CHILD_ES]
    iret


idle:
    jmp $

;时钟中断处理例程
clock_interrupt_handler:
    ;由于以下所有变量都在0x0000段，所以一定要先恢复ds，即使是从子进程进行时发出的时钟中断也需要恢复，回去的时候只需要在下面的某些判断过程再恢复ds即可
    mov ds,[OTHER_ES]

;首先更新当前进程的栈地址，每个更新段update_**都会跳回到下面的check_father，相当于一个函数调用
    cmp word [state_father],2 ;父进程位于运行态
    jz update_father
    cmp word [state_child],2 ;子进程位于运行态
    jz update_chlid
    ;否则当前是idle进程
    mov [IDLE_STACK],sp

;检测父进程是否处于睡眠态
check_father:
    cmp word [state_father], 0
    jz handle_father_sleep ;是则进行对应计数器减一操作以及进行睡眠时间是否结束的检测。如果睡眠时间结束，则修改父进程状态为就绪态；无论结没结束最后都会回跳到下面的check_child，因此实现两个进程的睡眠时间减一操作不会互相干扰
;检测子进程是否处于睡眠态
check_child:
    cmp word [state_child], 0
    jz handle_child_sleep  ;是则进行对应计数器减一操作以及进行睡眠时间是否结束的检测。如果睡眠时间结束，则修改子进程状态为就绪态；无论结没结束最后都会回跳到下面的choose
;完成以上的对于父进程和子进程的睡眠态处理后，无论它们处于什么状态，每次时钟中断发出后，都需要进行状态检测，并按照父进程>子进程>idle进程的优先级进行进程的选择与调度（因为idle是可以随时被打断的换成更高级的进程的，所以需要不断检测）
choose:
    ;父进程和子进程是否有在运行态的？有就什么都不干
    cmp word [state_father], 2
    jz back
    cmp word [state_child], 2
    mov ds,[CHILD_ES] ;假如子进程位于运行态，那么回去前先恢复ds为0x2000，否则下面也会重新初始化ds为0x0000
    jz back
    mov ds,[OTHER_ES]

    ;否则说明当前处于idle进程，那么需要进行父进程和子进程的状态检测，一旦有一个处于就绪态，就进行调度切换
    ;首先检测父进程是否处于就绪态(1)，是则进行调度切换
    cmp word [state_father], 1
    jz idle_to_father

    ;父进程不是处于就绪态，那么继续检测子进程是否处于就绪态(1)
    cmp word [state_child],1
    jz idle_to_child

    ;以上情况都不是，则原路返回，back封装了EOI以及iret
    jmp back
;到此时钟中断处理程序需要进行的一系列检测与调度就结束了，以下是一些上面用到的封装“函数”

;更新保存当前运行进程的栈地址，最后会回到时钟中断处理
update_father:
    mov [FATHER_STACK],sp
    jmp check_father
update_chlid:
    mov [CHILD_STACK],sp
    jmp check_father


;检测到父进程处于睡眠态后，进行对应计数器减一操作以及进行睡眠时间是否结束的检测。如果睡眠时间结束，则修改父进程状态为就绪态；无论结没结束最后都会回跳到时钟中断处理中的check_child
handle_father_sleep:
    cmp word [counter1],0
    mov word [state_father],1 ;恢复就绪态，这里用了假设的思路，假如上面的cmp成立，说明睡眠时间结束了，那么修改成就绪态后就跳回时钟中断处理，否则下面再恢复为睡眠态
    jz check_child ;时钟中断处理中的段标签
    ;进行到这说明睡眠未结束，将状态重新恢复为睡眠态，并进行减一操作，再返回时钟中断处理
    dec byte [counter1]
    mov word [state_father],0
    jmp check_child ;时钟中断处理中的段标签
;检测到子进程处于睡眠态后，进行对应计数器减一操作以及进行睡眠时间是否结束的检测。如果睡眠时间结束，则修改子进程状态为就绪态；无论结没结束最后都会回跳到时钟中断处理中的choose
handle_child_sleep:
    cmp word [counter2],0
    mov word [state_child],1 
    jz choose   ;时钟中断处理中的段标签

    dec byte [counter2]
    mov word [state_child],0
    jmp choose  ;时钟中断处理中的段标签

;从idle进程调度切换至父进程
idle_to_father:
    mov sp,[FATHER_STACK] ;切换栈
    mov word [state_father],2 ;修改父进程状态为运行态
    jmp back 
;从idle进程调度切换至子进程
idle_to_child:
    
    mov sp,[CHILD_STACK]
    mov word [state_child],2

    mov ss,[CHILD_ES]
    mov ds,[CHILD_ES]
    jmp back
;封装了EOI和iret,节省字节
back:
    mov al,20h
    out 20h,al
    iret

data:
counter1 dw 0  ; 父进程计数器
counter2 dw 0  ; 子进程计数器
counter3 dw 0  ; 用于write换行
state_father dw 2 ;记录父进程状态,0表示睡眠态，1表示就绪态，2为运行态
state_child  dw 1 ;记录子进程状态,0表示睡眠态，1表示就绪态，2为运行态

CHILD_ES dw 0x2000 ;子进程所在段地址
OTHER_ES dw 0x0000 ;父进程和idle以及内核所在段地址

FATHER_STACK dw 0x8000  ;父进程应用程序栈
IDLE_STACK dw 0x6000 ;idle栈
CHILD_STACK dw 0x9000  ;子进程应用程序栈

times 510-($-$$) db 0   ;填充剩余空间使程序大小为512字节
dw 0xAA55               ; MBR标志

