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
    mov sp,APPSTACK
    mov ss,ax

    ;写入中断向量表
    xor ax,ax
    mov ds,ax
    mov bx,32
    mov word [bx],clock_interrupt_handler-$$
    mov word [bx+2],07c0h

        ;write
    mov ds,ax
    mov bx,0x80*4
    mov word [bx],write_function-$$
    mov word [bx+2],07c0h

        ;sleep
    mov ds,ax
    mov bx,0x81*4
    mov word [bx],sleep_function-$$
    mov word [bx+2],07c0h

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

    ;sti
    ;加载app
    xor ax,ax
    mov es,ax 
    mov bx,0x8000       

    mov ah, 2       ; BIOS读取扇区功能号
    mov al, 1       ; 读取扇区的数量
    mov ch, 0       ; 柱面号清零
    mov cl, 2       ; 从第二个扇区开始
    mov dh, 0       ; 磁头号清零
    mov dl, 0x80       ; 使用默认的驱动器号

    int 0x13        ; 调用BIOS中断13h读取磁盘扇区
    ;jc disk_error   ; 如果读取失败，跳转到disk_error标签
    
    pushf
    push word 0 ;cs
    push word 0x8000 ;ip
    iret  ;从内核到应用程序执行
    

 ;int 80h
write_function:
    xor ax,ax
    mov ds,ax
    mov es,ax

    ;cx = 串长度
    mov bp,bx ; es:bp = 串地址
    mov ax,01301h ; ah = 13, al = 01h
    mov bx,000ch ;页号为 0(bh = 0) 黑底红字(bl = 0Ch,高亮)
    mov dh,[counter2]   ;显示的行号
    mov dl,39  ;显示的列号
    int 10h
    inc byte [counter2]
    cmp dh,24  ;当到达页面最后一行，那么返回第一行输出
    jz zero
    iret
zero:
    mov word [counter2],0
    iret


; int 81h
sleep_function:
    ; ax里装着秒数
    mov cx, 50 ; 将50存入cx寄存器
    imul ax, cx ; 将ax和cx的值相乘，结果存入ax
    mov [counter], ax ; 将ax的值存入counter
    inc byte [counter] ;加一方便时钟中断处理程序判断睡眠时间是否结束
    jmp wait_section ;切换进程

;进程切换程序：从app到idle
wait_section:
    ;保存调取中断前app的指令地址：由于在调用int 81h时会在应用程序栈压进中断前的地址，只要使用iret就能回去，故这一块不再重复保存调取中断前app的指令地址的操作，考虑在睡眠时间结束后直接切换回应用程序的栈，然后使用iret指令（sleep_back标签）
    ;保护现场：在idle进程只可能用到dx
    push dx
    ;换栈
    push bp
    mov bp,sp
    mov sp,CORESTACK ;切换栈

    pushf ;保存标志寄存器状态
    push word 0 ;cs
    push word idle ;ip
    iret ;使用iret从内核到进程函数idle
   

idle:
    sti
    jmp $

;时钟中断处理例程
clock_interrupt_handler:
    mov dx, [counter]
    cmp dx, 0
    jz skip_display ;如果为0则跳转，不执行

    cmp dx,1 ;如果为1，说明sleep已经结束了
    jz stop

    ;否则减1
    dec byte [counter]
    mov al,20h
    out 20h,al
    iret ;仍旧是返回idle

skip_display:
    mov al,20h
    out 20h,al
    ; 结束中断处理例程
    iret
;睡眠时间结束
stop:
    mov word [counter],0
    add sp,4 ;把返回idle的地址出栈
    push word 0 ;cs 
    push word wait_section_back ;IP 
    mov al,20h
    out 20h,al
    iret ;sleep已经结束了,那么跳到进程切换处理程序

;进程切换程序：从idle到app
wait_section_back:
    mov sp,bp  ;切换回app的栈
    pop bp
    pop dx ;恢复现场
    jmp sleep_back ;切换进程,回到app
sleep_back:
    iret  ;由于已经切换回app的栈，该栈的栈顶已经保存了app发出中断前的地址，此时iret就可以回到app

counter dw 0  ; 计数器变量，用于记录时钟中断触发次数
counter2 dw 0  ; write换行
APPSTACK equ 0200h  ;应用程序栈
CORESTACK equ 0x6000 ;idle栈
times 510-($-$$) db 0   ;填充剩余空间使程序大小为512字节
dw 0xAA55               ; MBR标志

