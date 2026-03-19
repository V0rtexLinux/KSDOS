/* ============================================================
   PIC - Programmable Interrupt Controller (8259A)
   Reference: https://wiki.osdev.org/8259_PIC
   ============================================================ */

#ifndef PIC_H
#define PIC_H

#include <stdint.h>

/* I/O ports */
#define PIC1_CMD   0x20
#define PIC1_DATA  0x21
#define PIC2_CMD   0xA0
#define PIC2_DATA  0xA1

/* PIC commands */
#define PIC_EOI    0x20   /* End-of-interrupt */

/* ICW1 */
#define PIC_ICW1_ICW4    0x01
#define PIC_ICW1_INIT    0x10

/* ICW4 */
#define PIC_ICW4_8086    0x01

/* Remap PIC1 to start at IRQ vector base1, PIC2 at base2 */
void pic_remap(uint8_t base1, uint8_t base2);

/* Send End-Of-Interrupt for a given IRQ (0..15) */
void pic_send_eoi(uint8_t irq);

/* Mask / unmask individual IRQ lines */
void pic_mask_irq(uint8_t irq);
void pic_unmask_irq(uint8_t irq);

#endif /* PIC_H */
