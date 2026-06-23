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
