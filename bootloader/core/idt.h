/* ============================================================
   IDT - Interrupt Descriptor Table
   Reference: https://wiki.osdev.org/Interrupt_Descriptor_Table
              https://wiki.osdev.org/8259_PIC
   ============================================================ */

#ifndef IDT_H
#define IDT_H

#include <stdint.h>

/* Gate types */
#define IDT_GATE_TASK    0x5
#define IDT_GATE_INT16   0x6
#define IDT_GATE_TRAP16  0x7
#define IDT_GATE_INT32   0xE
#define IDT_GATE_TRAP32  0xF

/* Descriptor Privilege Level */
#define IDT_DPL0  (0 << 5)
#define IDT_DPL3  (3 << 5)

/* Present flag */
#define IDT_PRESENT  (1 << 7)

/* A single IDT entry — 8 bytes */
typedef struct __attribute__((packed)) {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t  zero;
    uint8_t  type_attr;
    uint16_t offset_high;
} idt_entry_t;

/* IDTR — the register loaded by lidt */
typedef struct __attribute__((packed)) {
    uint16_t limit;
    uint32_t base;
} idt_descriptor_t;

/* CPU register state pushed by ISR stubs */
typedef struct __attribute__((packed)) {
    /* Pushed by pusha */
    uint32_t edi, esi, ebp, esp_ignored;
    uint32_t ebx, edx, ecx, eax;
    /* Pushed by ISR stub (interrupt number + error code) */
    uint32_t int_no, err_code;
    /* Pushed automatically by the CPU */
    uint32_t eip, cs, eflags, useresp, ss;
} cpu_regs_t;

void idt_init(void);
void isr_handler(cpu_regs_t *regs);
void irq_handler(cpu_regs_t *regs);

#endif /* IDT_H */
