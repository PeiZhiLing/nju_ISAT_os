app.bin:app.elf
	objcopy -R.eh_frame -R .comment -O binary app.elf app.bin

app.elf:main.o syscall.o 
	ld -m elf_i386 -T my.ld -e main main.o syscall.o -o app.elf

main.o:main_function.c myos.h
	gcc -m16 -I. -c main_function.c -o main.o

syscall.o:syscall.asm
	nasm -f elf32 syscall.asm -o syscall.o

qemu:
	qemu-img create -f raw disk.raw 10M
	nasm -f bin -o kernel.bin kernel.asm
	dd if=kernel.bin of=disk.raw bs=512 count=1
	dd if=app.bin of=disk.raw bs=512 seek=1 count=1
	qemu-system-x86_64 -drive file=disk.raw,format=raw

clean:
	rm app.elf syscall.o main.o kernel.bin disk.raw app.bin

