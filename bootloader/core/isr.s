/* ============================================================
   ISR / IRQ stubs — x86 32-bit AT&T syntax
   Reference: https://wiki.osdev.org/Interrupts
   ============================================================

   For CPU exceptions that push an error code the CPU leaves:
       [ss] [esp] [eflags] [cs] [eip] [error_code]  ← top of stack

   For exceptions that do NOT push an error code we push a dummy
   zero so that the layout is always identical for the C handler.

   After pushing the interrupt number we call the common stub which
   saves registers (pusha), calls the C handler, restores (popa)
   and returns with iret.
   ============================================================ */

.extern isr_handler
.extern irq_handler

/* ── common stub for CPU exceptions ─────────────────────────── */
isr_common_stub:
    pusha                   /* edi esi ebp esp ebx edx ecx eax */
    mov %ds, %ax
    push %eax               /* save data segment */

    mov $0x10, %ax          /* kernel data segment selector */
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    push %esp               /* pass pointer to cpu_regs_t */
    call isr_handler
    add $4, %esp

    pop %eax                /* restore data segment */
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    popa
    add $8, %esp            /* pop err_code + int_no */
    iret

/* ── common stub for hardware IRQs ──────────────────────────── */
irq_common_stub:
    pusha
    mov %ds, %ax
    push %eax

    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    push %esp
    call irq_handler
    add $4, %esp

    pop %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    popa
    add $8, %esp
    iret

/* ── macro helpers ───────────────────────────────────────────── */

/* Exception WITHOUT error code — push dummy 0 first */
.macro ISR_NOERR num
.global isr\num
isr\num:
    push $0
    push $\num
    jmp isr_common_stub
.endm

/* Exception WITH error code — CPU already pushed it */
.macro ISR_ERR num
.global isr\num
isr\num:
    push $\num
    jmp isr_common_stub
.endm

/* Hardware IRQ stub */
.macro IRQ num, vec
.global irq\num
irq\num:
    push $0
    push $\vec
    jmp irq_common_stub
.endm

/* ── CPU exception stubs (vectors 0 – 31) ───────────────────── */
ISR_NOERR 0     /* #DE Division By Zero           */
ISR_NOERR 1     /* #DB Debug                       */
ISR_NOERR 2     /*    NMI                           */
ISR_NOERR 3     /* #BP Breakpoint                  */
ISR_NOERR 4     /* #OF Overflow                    */
ISR_NOERR 5     /* #BR Bound Range Exceeded        */
ISR_NOERR 6     /* #UD Invalid Opcode              */
ISR_NOERR 7     /* #NM Device Not Available        */
ISR_ERR   8     /* #DF Double Fault (error=0)      */
ISR_NOERR 9     /*    Coprocessor Segment Overrun  */
ISR_ERR   10    /* #TS Invalid TSS                 */
ISR_ERR   11    /* #NP Segment Not Present         */
ISR_ERR   12    /* #SS Stack-Segment Fault         */
ISR_ERR   13    /* #GP General Protection Fault    */
ISR_ERR   14    /* #PF Page Fault                  */
ISR_NOERR 15    /*    Reserved                     */
ISR_NOERR 16    /* #MF x87 Floating-Point          */
ISR_ERR   17    /* #AC Alignment Check             */
ISR_NOERR 18    /* #MC Machine Check               */
ISR_NOERR 19    /* #XM SIMD Floating-Point         */
ISR_NOERR 20    /* #VE Virtualisation              */
ISR_NOERR 21
ISR_NOERR 22
ISR_NOERR 23
ISR_NOERR 24
ISR_NOERR 25
ISR_NOERR 26
ISR_NOERR 27
ISR_NOERR 28
ISR_NOERR 29
ISR_NOERR 30
ISR_NOERR 31

/* ── Hardware IRQ stubs (remapped to vectors 32 – 47) ───────── */
IRQ  0, 32    /* Timer (PIT)       */
IRQ  1, 33    /* Keyboard          */
IRQ  2, 34    /* Cascade (PIC2)    */
IRQ  3, 35    /* COM2              */
IRQ  4, 36    /* COM1              */
IRQ  5, 37    /* LPT2              */
IRQ  6, 38    /* Floppy            */
IRQ  7, 39    /* LPT1 / Spurious   */
IRQ  8, 40    /* CMOS RTC          */
IRQ  9, 41    /* Free / ACPI       */
IRQ 10, 42    /* Free / SCSI       */
IRQ 11, 43    /* Free / SCSI       */
IRQ 12, 44    /* PS/2 Mouse        */
IRQ 13, 45    /* FPU / Coprocessor */
IRQ 14, 46    /* ATA Primary       */
IRQ 15, 47    /* ATA Secondary     */
