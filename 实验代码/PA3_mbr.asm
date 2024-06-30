;设置代码段的起始位置
SECTION MBR vstart=0x7c00
_start:
    ;清屏
    mov ax, 0600h
    mov bx, 0700h
    mov cx, 0
    mov dx, 184fh
    int 10h

    cli
    ;写入中断向量表
    xor ax,ax
    mov ds,ax
    mov bx,0x70
    mov word [bx],clock_interrupt_handler-$$
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

    mov bp, sp
    ;开启中断
    sti
    jmp $

;时钟中断处理例程
clock_interrupt_handler:


    inc byte [counter]

    mov ax, [counter]
    cmp ax, 50
    jl skip_display ;未达到50次中断，那么不打印

    mov si,msg
    call print
    
    mov word [counter],0
    iret

skip_display:
    ;结束中断处理例程
    iret

print:
    ; 打印字符
    lodsb
    or al, al
    jz exit
    mov ah, 0x0E
    int 0x10          ; 调用INT 10h中断
    jmp print

exit:
    ret
msg db "Yong-Ming Tian ", 0

counter dw 0x00 ; 计数器变量，用于记录时钟中断触发次数
times 510-($-$$) db 0   ;填充剩余空间使程序大小为512字节
dw 0xAA55               ;MBR标志