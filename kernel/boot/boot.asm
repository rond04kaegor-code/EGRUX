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
