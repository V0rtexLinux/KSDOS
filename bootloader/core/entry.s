/* ============================================================
   KSDOS - OSDev-compliant Multiboot entry point
   Reference: https://wiki.osdev.org/Bare_Bones
   ============================================================ */

/* Multiboot 1 constants */
.set MB_ALIGN,    1<<0
.set MB_MEMINFO,  1<<1
.set MB_FLAGS,    MB_ALIGN | MB_MEMINFO
.set MB_MAGIC,    0x1BADB002
.set MB_CHECKSUM, -(MB_MAGIC + MB_FLAGS)

/* Multiboot header must be in first 8 KiB, 32-bit aligned */
.section .multiboot
.align 4
.long MB_MAGIC
.long MB_FLAGS
.long MB_CHECKSUM

/* ============================================================
   16 KiB kernel stack, 16-byte aligned per System V ABI
   ============================================================ */
.section .bss
.align 16
stack_bottom:
.skip 16384
stack_top:

/* ============================================================
   Kernel entry point
   GRUB / QEMU -kernel leaves us in 32-bit protected mode:
     - Interrupts disabled
     - Paging disabled
     - EAX = 0x2BADB002  (Multiboot magic)
     - EBX = pointer to Multiboot info structure
   ============================================================ */
.section .text
.global _start
.type _start, @function
_start:
    /* Set up the stack */
    mov $stack_top, %esp

    /* Push Multiboot args in right-to-left cdecl order:
       kernel_main(mb_magic, mb_info)
       → push mb_info (ebx) first, mb_magic (eax) second        */
    push %ebx        /* second arg: Multiboot info pointer       */
    push %eax        /* first  arg: Multiboot magic (0x2BADB002) */

    /* Initialise crucial processor state before entering kernel_main:
       - GDT is loaded inside kernel_main (gdt_init)
       - IDT is loaded inside kernel_main (idt_init)
       Floating-point and SIMD are not used by this kernel.           */

    /* Transfer control to the C kernel */
    call kernel_main

    /* kernel_main should never return; if it does, halt forever */
.Lhang:
    cli
    hlt
    jmp .Lhang

.size _start, . - _start
