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
