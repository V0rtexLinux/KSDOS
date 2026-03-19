/* ============================================================
   IDT - Interrupt Descriptor Table implementation
   Reference: https://wiki.osdev.org/Interrupt_Descriptor_Table
              https://wiki.osdev.org/8259_PIC
   ============================================================ */

#include "idt.h"
#include "isr.h"
#include "pic.h"

/* 256 possible vectors (0–255) */
#define IDT_ENTRIES 256

/* IRQ base vector after PIC remapping */
#define IRQ_BASE 32

static idt_entry_t     idt[IDT_ENTRIES];
static idt_descriptor_t idtr;

/* Exception names for the fault handler */
static const char *exception_names[] = {
    "Division By Zero",         /*  0 */
    "Debug",                    /*  1 */
    "Non-Maskable Interrupt",   /*  2 */
    "Breakpoint",               /*  3 */
    "Into Detected Overflow",   /*  4 */
    "Out of Bounds",            /*  5 */
    "Invalid Opcode",           /*  6 */
    "No Coprocessor",           /*  7 */
    "Double Fault",             /*  8 */
    "Coprocessor Seg Overrun",  /*  9 */
    "Bad TSS",                  /* 10 */
    "Segment Not Present",      /* 11 */
    "Stack Fault",              /* 12 */
    "General Protection Fault", /* 13 */
    "Page Fault",               /* 14 */
    "Unknown Interrupt",        /* 15 */
    "Coprocessor Fault",        /* 16 */
    "Alignment Check",          /* 17 */
    "Machine Check",            /* 18 */
    "SIMD Floating-Point",      /* 19 */
    "Virtualisation",           /* 20 */
    "Reserved",                 /* 21 */
    "Reserved",                 /* 22 */
    "Reserved",                 /* 23 */
    "Reserved",                 /* 24 */
    "Reserved",                 /* 25 */
    "Reserved",                 /* 26 */
    "Reserved",                 /* 27 */
    "Reserved",                 /* 28 */
    "Reserved",                 /* 29 */
    "Reserved",                 /* 30 */
    "Reserved"                  /* 31 */
};

/* VGA text-mode write helper (avoids pulling in the full kernel) */
static volatile unsigned short *const vga = (volatile unsigned short *)0xB8000;
static void panic_print(const char *s, int row) {
    int col = 0;
    while (*s && col < 80) {
        vga[row * 80 + col] = (unsigned short)(0x4F00 | (unsigned char)*s);
        s++; col++;
    }
}
static void panic_hex(unsigned int n, int row, int col_start) {
    static const char hex[] = "0123456789ABCDEF";
    int i;
    for (i = 7; i >= 0; i--) {
        vga[row * 80 + col_start + (7 - i)] =
            0x4F00 | hex[(n >> (i * 4)) & 0xF];
    }
}

/* ── ISR C handler ─────────────────────────────────────────── */
void isr_handler(cpu_regs_t *regs) {
    /* Display a simple panic screen on VGA row 0..4 */
    unsigned int i;
    for (i = 0; i < 80 * 5; i++) vga[i] = 0x4F20; /* red bg, space */

    panic_print("*** KERNEL EXCEPTION ***", 0);
    if (regs->int_no < 32)
        panic_print(exception_names[regs->int_no], 1);

    panic_print("INT=0x", 2); panic_hex(regs->int_no,  2, 6);
    panic_print("ERR=0x", 3); panic_hex(regs->err_code, 3, 6);
    panic_print("EIP=0x", 4); panic_hex(regs->eip,      4, 6);

    /* Halt forever */
    for (;;) {
        __asm__ volatile ("cli; hlt");
    }
}

/* ── IRQ C handler ─────────────────────────────────────────── */
void irq_handler(cpu_regs_t *regs) {
    /* PS/2 input is polled directly by the keyboard driver, so we
       just acknowledge the interrupt to the PIC and return.        */
    pic_send_eoi((uint8_t)(regs->int_no - IRQ_BASE));
}

/* ── IDT entry setup ───────────────────────────────────────── */
static void idt_set_gate(uint8_t num, uint32_t base,
                         uint16_t sel, uint8_t flags) {
    idt[num].offset_low  = (uint16_t)(base & 0xFFFF);
    idt[num].offset_high = (uint16_t)((base >> 16) & 0xFFFF);
    idt[num].selector    = sel;
    idt[num].zero        = 0;
    idt[num].type_attr   = flags;
}

/* ── Public init ───────────────────────────────────────────── */
void idt_init(void) {
    idtr.limit = (sizeof(idt_entry_t) * IDT_ENTRIES) - 1;
    idtr.base  = (uint32_t)&idt;

    /* Zero the entire table first */
    unsigned int i;
    for (i = 0; i < IDT_ENTRIES; i++) {
        idt_set_gate((uint8_t)i, 0, 0, 0);
    }

    /* Remap PIC: IRQ0–7 → vectors 32–39, IRQ8–15 → vectors 40–47 */
    pic_remap(IRQ_BASE, IRQ_BASE + 8);

    /* Install CPU exception handlers */
    uint8_t k = IDT_PRESENT | IDT_GATE_INT32 | IDT_DPL0;
    idt_set_gate( 0, (uint32_t)isr0,  0x08, k);
    idt_set_gate( 1, (uint32_t)isr1,  0x08, k);
    idt_set_gate( 2, (uint32_t)isr2,  0x08, k);
    idt_set_gate( 3, (uint32_t)isr3,  0x08, k);
    idt_set_gate( 4, (uint32_t)isr4,  0x08, k);
    idt_set_gate( 5, (uint32_t)isr5,  0x08, k);
    idt_set_gate( 6, (uint32_t)isr6,  0x08, k);
    idt_set_gate( 7, (uint32_t)isr7,  0x08, k);
    idt_set_gate( 8, (uint32_t)isr8,  0x08, k);
    idt_set_gate( 9, (uint32_t)isr9,  0x08, k);
    idt_set_gate(10, (uint32_t)isr10, 0x08, k);
    idt_set_gate(11, (uint32_t)isr11, 0x08, k);
    idt_set_gate(12, (uint32_t)isr12, 0x08, k);
    idt_set_gate(13, (uint32_t)isr13, 0x08, k);
    idt_set_gate(14, (uint32_t)isr14, 0x08, k);
    idt_set_gate(15, (uint32_t)isr15, 0x08, k);
    idt_set_gate(16, (uint32_t)isr16, 0x08, k);
    idt_set_gate(17, (uint32_t)isr17, 0x08, k);
    idt_set_gate(18, (uint32_t)isr18, 0x08, k);
    idt_set_gate(19, (uint32_t)isr19, 0x08, k);
    idt_set_gate(20, (uint32_t)isr20, 0x08, k);
    idt_set_gate(21, (uint32_t)isr21, 0x08, k);
    idt_set_gate(22, (uint32_t)isr22, 0x08, k);
    idt_set_gate(23, (uint32_t)isr23, 0x08, k);
    idt_set_gate(24, (uint32_t)isr24, 0x08, k);
    idt_set_gate(25, (uint32_t)isr25, 0x08, k);
    idt_set_gate(26, (uint32_t)isr26, 0x08, k);
    idt_set_gate(27, (uint32_t)isr27, 0x08, k);
    idt_set_gate(28, (uint32_t)isr28, 0x08, k);
    idt_set_gate(29, (uint32_t)isr29, 0x08, k);
    idt_set_gate(30, (uint32_t)isr30, 0x08, k);
    idt_set_gate(31, (uint32_t)isr31, 0x08, k);

    /* Install hardware IRQ handlers */
    idt_set_gate(32, (uint32_t)irq0,  0x08, k);
    idt_set_gate(33, (uint32_t)irq1,  0x08, k);
    idt_set_gate(34, (uint32_t)irq2,  0x08, k);
    idt_set_gate(35, (uint32_t)irq3,  0x08, k);
    idt_set_gate(36, (uint32_t)irq4,  0x08, k);
    idt_set_gate(37, (uint32_t)irq5,  0x08, k);
    idt_set_gate(38, (uint32_t)irq6,  0x08, k);
    idt_set_gate(39, (uint32_t)irq7,  0x08, k);
    idt_set_gate(40, (uint32_t)irq8,  0x08, k);
    idt_set_gate(41, (uint32_t)irq9,  0x08, k);
    idt_set_gate(42, (uint32_t)irq10, 0x08, k);
    idt_set_gate(43, (uint32_t)irq11, 0x08, k);
    idt_set_gate(44, (uint32_t)irq12, 0x08, k);
    idt_set_gate(45, (uint32_t)irq13, 0x08, k);
    idt_set_gate(46, (uint32_t)irq14, 0x08, k);
    idt_set_gate(47, (uint32_t)irq15, 0x08, k);

    /* Load the IDT */
    __asm__ volatile ("lidt (%0)" : : "r"(&idtr));

    /* Enable interrupts */
    __asm__ volatile ("sti");
}
