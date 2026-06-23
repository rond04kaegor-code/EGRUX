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
