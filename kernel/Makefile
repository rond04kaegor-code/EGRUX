ASM = nasm
CC = gcc
LD = ld
INCLUDES = -I./include -I../elibc/include
CFLAGS = -m32 -nostdlib -nostdinc -fno-builtin -fno-stack-protector -nostartfiles -nodefaultlibs -Wall $(INCLUDES) -c -O2
ASMFLAGS = -f elf32
LDFLAGS = -T linker.ld -m elf_i386

OBJS = boot/boot.o core/kernel.o core/gdt.o core/gdt_flush.o core/idt.o core/idt_load.o \
       core/isr.o core/irq.o core/utils.o drivers/screen.o drivers/keyboard.o fs/vfs.o

ELIBC_OBJS = ../elibc/lib/string.o ../elibc/lib/printf.o ../elibc/lib/stdio.o ../elibc/lib/unistd.o

all: kernel.bin
kernel.bin: $(OBJS) $(ELIBC_OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS) $(ELIBC_OBJS)

boot/%.o: boot/%.asm ; $(ASM) $(ASMFLAGS) -o $@ $<
core/%.o: core/%.asm ; $(ASM) $(ASMFLAGS) -o $@ $<
core/%.o: core/%.c ; $(CC) $(CFLAGS) -o $@ $<
drivers/%.o: drivers/%.c ; $(CC) $(CFLAGS) -o $@ $<
fs/%.o: fs/%.c ; $(CC) $(CFLAGS) -o $@ $<
clean: ; rm -f $(OBJS) kernel.bin
