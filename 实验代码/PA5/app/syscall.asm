BITS 16
section .text
    global write
    global sleep
    global fork

write:
    push ebp 
    mov  ebp, esp ;建临时栈
    push ebx ;保存要用到的寄存器
    push ecx 
    
    ;注意此处容易出错：在跳转write之前在栈中还会压入跳转前下一条指令的地址，所以第一个参数应该是+8
    mov  ebx, [ebp+8] ;第一个参数，字符串地址，char*类型
    mov  ecx, [ebp+12] ;第二个参数，字符串长度,在h头文件里是short类型

    int 0x80 ;write内核函数

    pop ecx
    pop ebx
    pop ebp

    retd ;32位回跳

sleep:
    push ebp
    mov ebp,esp
    push edx
    mov edx,[ebp+8]
    int 0x81
    pop edx
    pop ebp
    retd

fork:
    ;使用eax作为返回值传递
    ;此时仍旧是appstack
    mov eax,1
    push eax
    int 0x82
    ;要保证ax中是返回值
    pop eax
    retd

    
