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
