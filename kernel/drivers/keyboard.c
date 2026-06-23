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
