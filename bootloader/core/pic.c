/* ============================================================
   PIC - 8259A Programmable Interrupt Controller
   Reference: https://wiki.osdev.org/8259_PIC
   ============================================================ */

#include "pic.h"

/* Inline I/O helpers */
static inline void outb(uint16_t port, uint8_t val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}
static inline uint8_t inb(uint16_t port) {
    uint8_t val;
    __asm__ volatile ("inb %1, %0" : "=a"(val) : "Nd"(port));
    return val;
}
/* Short I/O delay — write to an unused port */
static inline void io_wait(void) {
    outb(0x80, 0);
}

/* Remap PIC1 → base1, PIC2 → base2 (avoids conflict with CPU exceptions) */
void pic_remap(uint8_t base1, uint8_t base2) {
    /* Save current masks */
    uint8_t mask1 = inb(PIC1_DATA);
    uint8_t mask2 = inb(PIC2_DATA);

    /* Initialise sequence (cascade mode) */
    outb(PIC1_CMD,  PIC_ICW1_INIT | PIC_ICW1_ICW4); io_wait();
    outb(PIC2_CMD,  PIC_ICW1_INIT | PIC_ICW1_ICW4); io_wait();

    /* ICW2: vector offsets */
    outb(PIC1_DATA, base1); io_wait();
    outb(PIC2_DATA, base2); io_wait();

    /* ICW3: cascade wiring */
    outb(PIC1_DATA, 4); io_wait();  /* PIC1 has slave on IRQ2 */
    outb(PIC2_DATA, 2); io_wait();  /* PIC2 cascade identity */

    /* ICW4: 8086 mode */
    outb(PIC1_DATA, PIC_ICW4_8086); io_wait();
    outb(PIC2_DATA, PIC_ICW4_8086); io_wait();

    /* Restore saved masks */
    outb(PIC1_DATA, mask1);
    outb(PIC2_DATA, mask2);
}

void pic_send_eoi(uint8_t irq) {
    if (irq >= 8)
        outb(PIC2_CMD, PIC_EOI);
    outb(PIC1_CMD, PIC_EOI);
}

void pic_mask_irq(uint8_t irq) {
    uint16_t port;
    if (irq < 8) {
        port = PIC1_DATA;
    } else {
        port = PIC2_DATA;
        irq -= 8;
    }
    outb(port, inb(port) | (1 << irq));
}

void pic_unmask_irq(uint8_t irq) {
    uint16_t port;
    if (irq < 8) {
        port = PIC1_DATA;
    } else {
        port = PIC2_DATA;
        irq -= 8;
    }
    outb(port, inb(port) & ~(1 << irq));
}
