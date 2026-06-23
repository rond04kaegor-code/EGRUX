#!/bin/bash

# egor-unix.sh - EGRUX Kernel FINAL WORKING
# Добавлена отладочная печать для диагностики

set -e

PROJECT_DIR="$HOME/egor-unix"
KERNEL_VERSION="1.0.0-1-generic"
KERNEL_ISO="egrux-${KERNEL_VERSION}.iso"
VMEGRUZ="vmegruz-${KERNEL_VERSION}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

print_step() { echo -e "${BLUE}[>]${NC} $1"; }
print_ok() { echo -e "${GREEN}  OK${NC} $1"; }
print_err() { echo -e "${RED}  ERROR${NC} $1"; exit 1; }

check_deps() {
    print_step "Checking dependencies..."
    for dep in nasm gcc ld make grub-mkrescue qemu-system-i386 xorriso cpio dd gzip; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            sudo apt-get update -qq 2>/dev/null || true
            sudo apt-get install -y -qq build-essential nasm gcc-multilib \
                grub-pc-bin xorriso qemu-system-x86 mtools cpio binutils gzip 2>/dev/null || true
            break
        fi
    done
    print_ok "Dependencies ready"
}

create_dirs() {
    print_step "Creating structure..."
    rm -rf "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR/kernel"/{boot,core,drivers,fs,include}
    mkdir -p "$PROJECT_DIR/elibc"/{include/sys,src,lib}
    mkdir -p "$PROJECT_DIR/modules"
    mkdir -p "$PROJECT_DIR/initrd"/{bin,sbin,lib/modules,dev,proc,sys,tmp,mnt/newroot}
    mkdir -p "$PROJECT_DIR/iso/boot/grub"
    mkdir -p "$PROJECT_DIR/distro"
    print_ok "Structure created"
}

build_elibc() {
    print_step "Building elibc..."
    mkdir -p "$PROJECT_DIR/elibc/include/sys"
    
    cat > "$PROJECT_DIR/elibc/include/stdint.h" << 'EOF'
#ifndef _STDINT_H
#define _STDINT_H
typedef signed char int8_t; typedef unsigned char uint8_t;
typedef signed short int16_t; typedef unsigned short uint16_t;
typedef signed int int32_t; typedef unsigned int uint32_t;
typedef int32_t ssize_t; typedef uint32_t size_t;
typedef int32_t intptr_t; typedef uint32_t uintptr_t;
#define NULL ((void*)0)
#endif
EOF

    cat > "$PROJECT_DIR/elibc/include/stddef.h" << 'EOF'
#ifndef _STDDEF_H
#define _STDDEF_H
#include <stdint.h>
#define NULL ((void*)0)
#endif
EOF

    cat > "$PROJECT_DIR/elibc/include/stdarg.h" << 'EOF'
#ifndef _STDARG_H
#define _STDARG_H
typedef __builtin_va_list va_list;
#define va_start(v,l) __builtin_va_start(v,l)
#define va_end(v) __builtin_va_end(v)
#define va_arg(v,l) __builtin_va_arg(v,l)
#endif
EOF

    cat > "$PROJECT_DIR/elibc/include/string.h" << 'EOF'
#ifndef _STRING_H
#define _STRING_H
#include <stddef.h>
void *memset(void *s, int c, size_t n);
void *memcpy(void *dest, const void *src, size_t n);
size_t strlen(const char *s);
int strcmp(const char *s1, const char *s2);
#endif
EOF

    cat > "$PROJECT_DIR/elibc/include/stdio.h" << 'EOF'
#ifndef _STDIO_H
#define _STDIO_H
#include <stdarg.h>
#include <stddef.h>
int printf(const char *format, ...);
int putchar(int c);
int getchar(void);
#endif
EOF

    cat > "$PROJECT_DIR/elibc/include/unistd.h" << 'EOF'
#ifndef _UNISTD_H
#define _UNISTD_H
#include <stdint.h>
#define STDIN_FILENO 0
#define STDOUT_FILENO 1
ssize_t read(int fd, void *buf, size_t count);
ssize_t write(int fd, const void *buf, size_t count);
void _exit(int status);
#endif
EOF

    cat > "$PROJECT_DIR/elibc/src/string.c" << 'EOF'
#include <string.h>
void *memset(void *s, int c, size_t n) { unsigned char *p=(unsigned char*)s; while(n--)*p++=(unsigned char)c; return s; }
void *memcpy(void *d, const void *s, size_t n) { unsigned char *dd=(unsigned char*)d; const unsigned char *ss=(const unsigned char*)s; while(n--)*dd++=*ss++; return d; }
size_t strlen(const char *s) { size_t l=0; while(*s++)l++; return l; }
int strcmp(const char *a, const char *b) { while(*a&&*a==*b){a++;b++;} return*(const unsigned char*)a-*(const unsigned char*)b; }
EOF

    cat > "$PROJECT_DIR/elibc/src/printf.c" << 'EOF'
#include <stdio.h>
#include <string.h>
static void itoa(unsigned int v, char *s, int b, int sign) {
    int i=0; if(v==0){s[i++]='0';s[i]=0;return;}
    while(v){int r=(int)(v%(unsigned)b);s[i++]=(char)((r>9)?r-10+'a':r+'0');v/=(unsigned)b;}
    if(sign)s[i++]='-'; s[i]=0;
    for(int j=0,k=i-1;j<k;j++,k--){char t=s[j];s[j]=s[k];s[k]=t;}
}
int vsnprintf(char *buf, size_t sz, const char *fmt, va_list ap) {
    if(!buf||!sz)return 0; size_t w=0; char tmp[32];
    while(*fmt&&w<sz-1){if(*fmt!='%'){buf[w++]=*fmt++;continue;} fmt++;
        switch(*fmt){
            case 'd':{int v=va_arg(ap,int);unsigned u=(unsigned)(v<0?-v:v);itoa(u,tmp,10,v<0);for(char*p=tmp;*p&&w<sz-1;p++)buf[w++]=*p;break;}
            case 's':{char*s=va_arg(ap,char*);if(!s)s="(null)";while(*s&&w<sz-1)buf[w++]=*s++;break;}
            case 'c':buf[w++]=(char)va_arg(ap,int);break;
            case '%':buf[w++]='%';break;
        } fmt++;
    } buf[w]=0; return (int)w;
}
int printf(const char *f, ...){char b[4096];va_list a;va_start(a,f);int r=vsnprintf(b,sizeof(b),f,a);va_end(a);for(int i=0;i<r;i++)putchar(b[i]);return r;}
EOF

    cat > "$PROJECT_DIR/elibc/src/stdio.c" << 'EOF'
#include <stdio.h>
#include <unistd.h>
int putchar(int c) { char ch=(char)c; write(STDOUT_FILENO,&ch,1); return (unsigned char)c; }
int getchar(void) { char c; if(read(STDIN_FILENO,&c,1)!=1)return -1; return (unsigned char)c; }
EOF

    cat > "$PROJECT_DIR/elibc/src/unistd.c" << 'EOF'
#include <unistd.h>
#include <stdint.h>
static int syscall(int n, int a, int b, int c){int r;asm volatile("int $0x80":"=a"(r):"a"(n),"b"(a),"c"(b),"d"(c):"memory");return r;}
ssize_t read(int fd, void *buf, size_t n){return(ssize_t)syscall(3,fd,(int)(uintptr_t)buf,(int)n);}
ssize_t write(int fd, const void *buf, size_t n){return(ssize_t)syscall(4,fd,(int)(uintptr_t)buf,(int)n);}
void _exit(int s){syscall(1,s,0,0);while(1){asm volatile("hlt");}}
EOF

    cd "$PROJECT_DIR/elibc"
    rm -f lib/*.o lib/libc.a 2>/dev/null; mkdir -p lib
    CF="-m32 -nostdlib -nostdinc -fno-builtin -fno-stack-protector -I./include -O2 -c"
    gcc $CF src/string.c -o lib/string.o || print_err "string.c"
    gcc $CF src/printf.c -o lib/printf.o || print_err "printf.c"
    gcc $CF src/stdio.c -o lib/stdio.o || print_err "stdio.c"
    gcc $CF src/unistd.c -o lib/unistd.o || print_err "unistd.c"
    ar rcs lib/libc.a lib/string.o lib/printf.o lib/stdio.o lib/unistd.o
    print_ok "elibc built"
    cd "$PROJECT_DIR"
}

build_initrd() {
    print_step "Building initrd..."
    cd "$PROJECT_DIR/initrd"
    cat > init << 'EOF'
#!/bin/sh
echo "EGRUX initrd boot"
mount -t proc none /proc 2>/dev/null
mount -t sysfs none /sys 2>/dev/null
for dev in /dev/sda1 /dev/sdb1; do
    if mount -t fat32 "$dev" /mnt/newroot 2>/dev/null; then
        for d in bin sbin etc lib; do cp -r "/$d"/* "/mnt/newroot/$d/" 2>/dev/null; done
        mount --move /proc /mnt/newroot/proc 2>/dev/null
        mount --move /sys /mnt/newroot/sys 2>/dev/null
        exec switch_root /mnt/newroot /sbin/init
    fi
done
exec /bin/sh
EOF
    chmod +x init
    mkdir -p sbin bin lib/modules
    echo '#!/bin/sh
echo "EGRUX on real FS"
exec /bin/sh' > sbin/init
    chmod +x sbin/init
    echo '#!/bin/sh
while true; do printf "egrux> "; read cmd || break
case "$cmd" in help) echo "help exit ls";; exit) exit 0;; ls) ls /;; esac
done' > bin/sh
    chmod +x bin/sh
    cd "$PROJECT_DIR"
    mkdir -p modules
    for mod in fat32 ext2 ext3 ext4; do
        echo "int ${mod}_init(void) { return 0; }" > "modules/${mod}.c"
        gcc -m32 -nostdlib -nostdinc -fno-builtin -I"elibc/include" -c "modules/${mod}.c" -o "initrd/lib/modules/${mod}.o" 2>/dev/null || touch "initrd/lib/modules/${mod}.o"
    done
    rm -f initrd.img
    cd "$PROJECT_DIR/initrd"
    find . | cpio -o -H newc > "$PROJECT_DIR/initrd.img" 2>/dev/null
    cd "$PROJECT_DIR"
    print_ok "initrd.img created"
}

build_kernel() {
    print_step "Building EGRUX KERNEL..."

    cat > "$PROJECT_DIR/kernel/include/kernel.h" << 'EOF'
#ifndef KERNEL_H
#define KERNEL_H
#include <stdint.h>
#include <stddef.h>
#define EGRUX_VERSION "1.0.0-1-generic"

typedef struct { uint32_t flags,mem_lower,mem_upper,boot_device,cmdline,mods_count,mods_addr; } multiboot_info_t;
typedef struct { uint32_t mod_start,mod_end,cmdline,pad; } multiboot_module_t;

void kernel_main(uint32_t magic, multiboot_info_t *mbd);
void console_init(void);
void console_putchar(char c);
void console_write(const char *s);
void console_set_color(uint8_t f, uint8_t b);
void console_write_dec(uint32_t n);
void console_write_hex(uint32_t n);
void read_line(char *b, int m);
void gdt_init(void);
void idt_init(void);
void keyboard_init(void);
char keyboard_getchar(void);
void irq_install_handler(int irq, void (*handler)(void));
void panic_shell(void);
void panic_with_type(int type, const char *msg);
uint8_t inb(uint16_t p);
void outb(uint16_t p, uint8_t v);
void initrd_init(multiboot_module_t *m);
#endif
EOF

    cat > "$PROJECT_DIR/kernel/core/kernel.c" << 'EOF'
#include <kernel.h>
#include <string.h>

// Прямая запись в VGA без использования printf
void kernel_main(uint32_t magic, multiboot_info_t *mbd) {
    // 1. Инициализация VGA
    console_init();
    
    // 2. Вывод ТОЛЬКО через console_write (не printf!)
    console_set_color(0x0F, 0x00);  // White on black
    console_write("\n");
    console_set_color(0x0E, 0x00);  // Yellow
    console_write("============================================\n");
    console_write("  EGRUX KERNEL v1.0.0-1-generic\n");
    console_write("============================================\n\n");
    console_set_color(0x0F, 0x00);
    
    // 3. Проверка magic
    console_set_color(0x0B, 0x00);  // Cyan
    console_write("[DEBUG] Magic: 0x");
    console_write_hex(magic);
    console_write("\n");
    
    if (magic != 0x2BADB002) {
        console_set_color(0x04, 0x00);  // Red
        console_write("ERROR: Bad magic number!\n");
        while(1) {}
    }
    
    // 4. GDT
    console_set_color(0x0A, 0x00);  // Green
    console_write("[DEBUG] Installing GDT...\n");
    gdt_init();
    console_write("[OK] GDT installed\n");
    
    // 5. IDT
    console_write("[DEBUG] Installing IDT...\n");
    idt_init();
    console_write("[OK] IDT installed\n");
    
    // 6. Keyboard
    console_write("[DEBUG] Initializing keyboard...\n");
    keyboard_init();
    console_write("[OK] Keyboard ready\n");
    
    // 7. Проверка initrd
    if (mbd->mods_count > 0) {
        console_write("[DEBUG] initrd found, count: ");
        console_write_dec(mbd->mods_count);
        console_write("\n");
        initrd_init((multiboot_module_t*)mbd->mods_addr);
    } else {
        console_write("[DEBUG] No initrd modules\n");
    }
    
    // 8. Готово
    console_set_color(0x0F, 0x00);
    console_write("\n");
    console_write("Type 'help' for commands\n");
    console_write("Type 'panic' for panic menu\n");
    console_write("\n");
    
    // 9. Основной цикл
    char cmd[256];
    while (1) {
        console_set_color(0x0B, 0x00);
        console_write("egrux# ");
        console_set_color(0x0F, 0x00);
        
        read_line(cmd, sizeof(cmd));
        
        if (strcmp(cmd, "help") == 0) {
            console_write("\nCommands: help version clear panic halt reboot\n");
            console_write("Panic types: panic1 panic2 panic3 panic4 panic5\n");
            console_write("            panic6 panic7 panic8 panic9 panic10\n\n");
        }
        else if (strcmp(cmd, "version") == 0) {
            console_write("EGRUX KERNEL v1.0.0-1-generic\n");
        }
        else if (strcmp(cmd, "clear") == 0) {
            console_write("\033[2J\033[H");
        }
        else if (strcmp(cmd, "panic") == 0) {
            panic_shell();
        }
        else if (strcmp(cmd, "panic1") == 0) {
            panic_with_type(1, "Kernel Oops");
        }
        else if (strcmp(cmd, "panic2") == 0) {
            console_set_color(0x4F, 0x00);
            console_write("\n*** KERNEL PANIC: NULL Pointer ***\n");
            console_write("System halted.\n");
            while(1) {}
        }
        else if (strcmp(cmd, "panic3") == 0) {
            console_set_color(0x4F, 0x00);
            console_write("\n*** KERNEL PANIC: Division by Zero ***\n");
            console_write("System halted.\n");
            while(1) {}
        }
        else if (strcmp(cmd, "halt") == 0) {
            console_write("System halted.\n");
            while(1) { asm volatile("hlt"); }
        }
        else if (strcmp(cmd, "reboot") == 0) {
            console_write("Rebooting...\n");
            outb(0x64, 0xFE);
            while(1) {}
        }
        else if (strlen(cmd) > 0) {
            console_write("Unknown command: ");
            console_write(cmd);
            console_write("\n");
        }
    }
}

void panic_shell(void) {
    console_set_color(0x4F, 0x00);
    console_write("\n=== KERNEL PANIC MENU ===\n");
    console_write("  panic1 - Kernel Oops\n");
    console_write("  panic2 - NULL Pointer\n");
    console_write("  panic3 - Division by Zero\n");
    console_set_color(0x0F, 0x00);
}

void panic_with_type(int type, const char *msg) {
    console_set_color(0x4F, 0x00);
    console_write("\n\n*** KERNEL PANIC ***\n");
    console_write("Type: "); console_write(msg); console_write("\n");
    console_write("Kernel: EGRUX v1.0.0-1-generic\n");
    console_write("---[ end Kernel panic - not syncing ]---\n\n");
    console_write("System halted.\n");
    console_set_color(0x0F, 0x00);
    while(1) { asm volatile("hlt"); }
}

void initrd_init(multiboot_module_t *m) {
    console_write("[DEBUG] initrd at 0x");
    console_write_hex(m->mod_start);
    console_write(", size: ");
    console_write_dec(m->mod_end - m->mod_start);
    console_write("\n");
}
EOF

    # Assembly files
    cat > "$PROJECT_DIR/kernel/boot/boot.asm" << 'EOF'
[BITS 32]
global start
extern kernel_main

MBOOT_MAGIC equ 0x1BADB002
MBOOT_FLAGS equ 3
MBOOT_CHECK equ -(MBOOT_MAGIC+MBOOT_FLAGS)

section .multiboot
    dd MBOOT_MAGIC
    dd MBOOT_FLAGS
    dd MBOOT_CHECK

section .bss
align 16
stack_bottom:
    resb 65536
stack_top:

section .text
start:
    mov esp, stack_top
    push 0
    popf
    push ebx
    push eax
    call kernel_main
    cli
.hang:
    hlt
    jmp .hang
EOF

    cat > "$PROJECT_DIR/kernel/core/gdt_flush.asm" << 'EOF'
global gdt_flush

gdt_flush:
    mov eax, [esp+4]
    lgdt [eax]
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 0x08:.flush
.flush:
    ret
EOF

    cat > "$PROJECT_DIR/kernel/core/idt_load.asm" << 'EOF'
global idt_load

idt_load:
    mov eax, [esp+4]
    lidt [eax]
    sti
    ret
EOF

    cat > "$PROJECT_DIR/kernel/core/isr.asm" << 'EOF'
global irq0_handler
global irq1_handler
global default_isr
extern irq_handler

irq0_handler:
    pusha
    push 0
    call irq_handler
    add esp, 4
    popa
    iret

irq1_handler:
    pusha
    push 1
    call irq_handler
    add esp, 4
    popa
    iret

default_isr:
    pusha
    popa
    iret
EOF

    # C files
    cat > "$PROJECT_DIR/kernel/core/gdt.c" << 'EOF'
#include <kernel.h>
struct gdt_entry { uint16_t limit_low, base_low; uint8_t base_mid, access, gran, base_high; } __attribute__((packed));
struct gdt_ptr { uint16_t limit; uint32_t base; } __attribute__((packed));
static struct gdt_entry gdt[3];
static struct gdt_ptr gp;
extern void gdt_flush(uint32_t);

static void gdt_set_gate(int n, uint32_t base, uint32_t limit, uint8_t access, uint8_t gran) {
    gdt[n].base_low = base & 0xFFFF;
    gdt[n].base_mid = (base >> 16) & 0xFF;
    gdt[n].base_high = (base >> 24) & 0xFF;
    gdt[n].limit_low = limit & 0xFFFF;
    gdt[n].gran = ((limit >> 16) & 0x0F) | (gran & 0xF0);
    gdt[n].access = access;
}

void gdt_init(void) {
    gp.limit = sizeof(gdt) - 1;
    gp.base = (uint32_t)&gdt;
    
    gdt_set_gate(0, 0, 0, 0, 0);           // NULL
    gdt_set_gate(1, 0, 0xFFFFFFFF, 0x9A, 0xCF);  // Code
    gdt_set_gate(2, 0, 0xFFFFFFFF, 0x92, 0xCF);  // Data
    
    gdt_flush((uint32_t)&gp);
}
EOF

    cat > "$PROJECT_DIR/kernel/core/idt.c" << 'EOF'
#include <kernel.h>
#include <string.h>

struct idt_entry {
    uint16_t base_lo;
    uint16_t sel;
    uint8_t  zero;
    uint8_t  flags;
    uint16_t base_hi;
} __attribute__((packed));

struct idt_ptr {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

static struct idt_entry idt[256];
static struct idt_ptr idtp;

extern void idt_load(uint32_t);
extern void default_isr(void);
extern void irq0_handler(void);
extern void irq1_handler(void);
void irq_init(void);

static void idt_set_gate(uint8_t n, uint32_t base, uint16_t sel, uint8_t flags) {
    idt[n].base_lo = base & 0xFFFF;
    idt[n].base_hi = (base >> 16) & 0xFFFF;
    idt[n].sel = sel;
    idt[n].zero = 0;
    idt[n].flags = flags;
}

void idt_init(void) {
    idtp.limit = sizeof(idt) - 1;
    idtp.base = (uint32_t)&idt;
    
    memset(&idt, 0, sizeof(idt));
    
    // Все векторы -> default_isr
    for (int i = 0; i < 256; i++) {
        idt_set_gate(i, (uint32_t)&default_isr, 0x08, 0x8E);
    }
    
    // IRQ0 -> вектор 32
    idt_set_gate(32, (uint32_t)&irq0_handler, 0x08, 0x8E);
    // IRQ1 -> вектор 33
    idt_set_gate(33, (uint32_t)&irq1_handler, 0x08, 0x8E);
    
    irq_init();
    idt_load((uint32_t)&idtp);
}
EOF

    cat > "$PROJECT_DIR/kernel/core/irq.c" << 'EOF'
#include <kernel.h>

static void (*irq_handlers[16])(void);

void irq_install_handler(int irq, void (*handler)(void)) {
    if (irq >= 0 && irq < 16) {
        irq_handlers[irq] = handler;
    }
}

void irq_init(void) {
    // Save masks
    uint8_t m1 = inb(0x21);
    uint8_t m2 = inb(0xA1);
    
    // Start initialization
    outb(0x20, 0x11);
    outb(0xA0, 0x11);
    
    // Set vector offsets
    outb(0x21, 0x20);  // Master: IRQ0-7 -> INT 32-39
    outb(0xA1, 0x28);  // Slave:  IRQ8-15 -> INT 40-47
    
    // Tell master about slave
    outb(0x21, 0x04);
    outb(0xA1, 0x02);
    
    // Set x86 mode
    outb(0x21, 0x01);
    outb(0xA1, 0x01);
    
    // Restore masks (disable all)
    outb(0x21, 0xFF);
    outb(0xA1, 0xFF);
    
    // Clear handlers
    for (int i = 0; i < 16; i++) {
        irq_handlers[i] = NULL;
    }
    
    // Enable ONLY IRQ1 (keyboard)
    outb(0x21, 0xFD);  // 11111101
}

void irq_handler(int n) {
    if (irq_handlers[n]) {
        irq_handlers[n]();
    }
    
    // Send EOI
    if (n >= 8) {
        outb(0xA0, 0x20);
    }
    outb(0x20, 0x20);
}
EOF

    cat > "$PROJECT_DIR/kernel/core/utils.c" << 'EOF'
#include <kernel.h>

uint8_t inb(uint16_t port) {
    uint8_t result;
    asm volatile("inb %1, %0" : "=a"(result) : "Nd"(port));
    return result;
}

void outb(uint16_t port, uint8_t value) {
    asm volatile("outb %0, %1" :: "a"(value), "Nd"(port));
}
EOF

    cat > "$PROJECT_DIR/kernel/drivers/screen.c" << 'EOF'
#include <kernel.h>

static uint16_t *video_memory = (uint16_t*)0xB8000;
static uint8_t cursor_x = 0;
static uint8_t cursor_y = 0;
static uint8_t color = 0x0F;

void console_init(void) {
    for (int i = 0; i < 80 * 25; i++) {
        video_memory[i] = (uint16_t)((color << 8) | ' ');
    }
    cursor_x = 0;
    cursor_y = 0;
    // Update hardware cursor
    outb(0x3D4, 14);
    outb(0x3D5, 0);
    outb(0x3D4, 15);
    outb(0x3D5, 0);
}

void console_set_color(uint8_t fg, uint8_t bg) {
    color = (uint8_t)((bg << 4) | (fg & 0x0F));
}

void console_putchar(char c) {
    if (c == '\n') {
        cursor_x = 0;
        cursor_y++;
    } else if (c == '\b' && cursor_x > 0) {
        cursor_x--;
        video_memory[cursor_y * 80 + cursor_x] = (uint16_t)((color << 8) | ' ');
    } else if (c >= ' ') {
        video_memory[cursor_y * 80 + cursor_x] = (uint16_t)((color << 8) | (unsigned char)c);
        cursor_x++;
    }
    
    if (cursor_x >= 80) {
        cursor_x = 0;
        cursor_y++;
    }
    
    if (cursor_y >= 25) {
        for (int i = 0; i < 24 * 80; i++) {
            video_memory[i] = video_memory[i + 80];
        }
        for (int i = 24 * 80; i < 25 * 80; i++) {
            video_memory[i] = (uint16_t)((color << 8) | ' ');
        }
        cursor_y = 24;
    }
    
    // Update hardware cursor
    uint16_t pos = (uint16_t)(cursor_y * 80 + cursor_x);
    outb(0x3D4, 14);
    outb(0x3D5, (uint8_t)(pos >> 8));
    outb(0x3D4, 15);
    outb(0x3D5, (uint8_t)(pos & 0xFF));
}

void console_write(const char *s) {
    while (*s) {
        console_putchar(*s++);
    }
}

void console_write_hex(uint32_t n) {
    console_write("0x");
    char hex[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4) {
        console_putchar(hex[(n >> i) & 0xF]);
    }
}

void console_write_dec(uint32_t n) {
    if (n == 0) {
        console_putchar('0');
        return;
    }
    char buf[32];
    int i = 30;
    buf[31] = '\0';
    while (n > 0) {
        buf[i--] = '0' + (n % 10);
        n /= 10;
    }
    console_write(&buf[i + 1]);
}

void read_line(char *buf, int max) {
    int i = 0;
    while (1) {
        char c = keyboard_getchar();
        if (c == '\n' || c == '\r') {
            buf[i] = '\0';
            console_write("\n");
            break;
        } else if (c == '\b') {
            if (i > 0) {
                console_write("\b \b");
                i--;
            }
        } else if (c >= ' ' && i < max - 1) {
            buf[i++] = c;
            console_putchar(c);
        }
    }
}
EOF

    cat > "$PROJECT_DIR/kernel/drivers/keyboard.c" << 'EOF'
#include <kernel.h>

static unsigned char kbd_map[128] = {
    0,    27,   '1',  '2',  '3',  '4',  '5',  '6',
    '7',  '8',  '9',  '0',  '-',  '=',  '\b', '\t',
    'q',  'w',  'e',  'r',  't',  'y',  'u',  'i',
    'o',  'p',  '[',  ']',  '\n', 0,    'a',  's',
    'd',  'f',  'g',  'h',  'j',  'k',  'l',  ';',
    '\'', '`',  0,    '\\', 'z',  'x',  'c',  'v',
    'b',  'n',  'm',  ',',  '.',  '/',  0,    '*',
    0,    ' ',  0,    0,    0,    0,    0,    0
};

static volatile char kbd_buffer[256];
static volatile int kbd_head = 0;
static volatile int kbd_tail = 0;

static void keyboard_handler(void) {
    uint8_t scancode = inb(0x60);
    if (!(scancode & 0x80)) {
        char c = (char)kbd_map[scancode & 0x7F];
        if (c) {
            int next = (kbd_tail + 1) % 256;
            if (next != kbd_head) {
                kbd_buffer[kbd_tail] = c;
                kbd_tail = next;
            }
        }
    }
}

void keyboard_init(void) {
    irq_install_handler(1, keyboard_handler);
}

char keyboard_getchar(void) {
    while (kbd_head == kbd_tail) {
        asm volatile("hlt");
    }
    char c = kbd_buffer[kbd_head];
    kbd_head = (kbd_head + 1) % 256;
    return c;
}
EOF

    echo '#include <kernel.h>
void vfs_init(void) {}
void fat32_init(void) {}' > "$PROJECT_DIR/kernel/fs/vfs.c"

    # Makefile
    cat > "$PROJECT_DIR/kernel/Makefile" << 'MAKEEOF'
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
MAKEEOF

    cat > "$PROJECT_DIR/kernel/linker.ld" << 'EOF'
ENTRY(start)
SECTIONS {
    . = 1M;
    .text : { *(.multiboot) *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(COMMON) *(.bss) }
}
EOF

    cd "$PROJECT_DIR/kernel"
    make clean 2>/dev/null || true
    echo "  Compiling kernel..."
    if make 2>&1; then
        print_ok "KERNEL: kernel.bin ($(stat -c%s kernel.bin) bytes)"
    else
        print_err "Kernel build failed!"
    fi
    cd "$PROJECT_DIR"
}

create_iso() {
    print_step "Creating ISO..."
    cd "$PROJECT_DIR"
    gzip -9 -c kernel/kernel.bin > "$VMEGRUZ" 2>/dev/null || true
    mkdir -p iso/boot/grub
    cp kernel/kernel.bin iso/boot/
    cat > iso/boot/grub/grub.cfg << 'EOF'
set timeout=5
menuentry "EGRUX KERNEL" { multiboot /boot/kernel.bin; boot }
EOF
    grub-mkrescue -o "$KERNEL_ISO" iso/ 2>/dev/null || print_err "ISO failed!"
    print_ok "ISO: ${KERNEL_ISO} ($(stat -c%s $KERNEL_ISO) bytes)"
    cd "$PROJECT_DIR"
}

run_qemu() {
    print_step "Starting QEMU..."
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  EGRUX KERNEL - Debug Mode${NC}"
    echo -e "${GREEN}  You should see [DEBUG] messages${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    sleep 2
    qemu-system-i386 -cdrom "$KERNEL_ISO" -m 128M -boot d -no-reboot -serial stdio &
    QEMU_PID=$!
    echo -e "${YELLOW}QEMU PID: ${QEMU_PID}${NC}"
    wait $QEMU_PID 2>/dev/null || true
}

main() {
    echo -e "${CYAN}EGRUX KERNEL Builder - Debug Version${NC}"
    check_deps
    create_dirs
    build_elibc
    build_initrd
    build_kernel
    create_iso
    echo -e "\n${GREEN}BUILD COMPLETE!${NC}"
    run_qemu
}

main
