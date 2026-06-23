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
