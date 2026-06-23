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
