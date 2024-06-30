app.bin:app.elf
	objcopy -R.eh_frame -R .comment -O binary ./output/app.elf ./output/app.bin

app.elf:main.o syscall.o 
	ld -m elf_i386 -T my.ld -e main ./output/main.o ./output/syscall.o -o ./output/app.elf

main.o:main_function.c myos.h
	gcc -m16 -ffreestanding -fno-pic  -I. -c main_function.c -o ./output/main.o

syscall.o:syscall.asm
	nasm -f elf32 syscall.asm -o ./output/syscall.o

qemu:
	qemu-img create -f raw disk.raw 10M
	nasm -f bin -o ./output/kernel.bin kernel.asm
	dd if=./output/kernel.bin of=disk.raw bs=512 count=1
	dd if=./output/app.bin of=disk.raw bs=512 seek=1 count=1
	qemu-system-x86_64 -drive file=disk.raw,format=raw

clean:
	rm app.elf syscall.o main.o

