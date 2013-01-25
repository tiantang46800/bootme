CROSS_COMPILE=arm-none-linux-gnueabi-
OBJS:=start.o
u-boot.bin:$(OBJS)
	$(CROSS_COMPILE)ld -Tmap.lds -Ttext=0x34000 -o u-boot.elf $^
	#$(CROSS_COMPILE)ld -Tmap.lds -Ttext=0x34000 -o u-boot.elf $^
	$(CROSS_COMPILE)objcopy -O binary u-boot.elf u-boot.bin
	$(CROSS_COMPILE)objdump -D u-boot.elf > u-boot.dis
%.o:%.S
	$(CROSS_COMPILE)gcc -O0 -nostdlib -fno-builtin -g -c -o $@ $<
%.o:%.c
	$(CROSS_COMPILE)gcc -O0 -nostdlib -fno-builtin -g -c -o $@ $<
clean:
	rm -rf *.bin *.elf *.o *.dis
