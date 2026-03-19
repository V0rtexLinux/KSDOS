/* ============================================================
   GDT - Global Descriptor Table
   Reference: https://wiki.osdev.org/Global_Descriptor_Table
              https://wiki.osdev.org/GDT_Tutorial
   ============================================================ */

#ifndef GDT_H
#define GDT_H

#include <stdint.h>

/* GDT segment selectors */
#define GDT_KERNEL_CODE  0x08
#define GDT_KERNEL_DATA  0x10
#define GDT_USER_CODE    0x18
#define GDT_USER_DATA    0x20

/* Access byte flags */
#define GDT_ACCESS_PRESENT    (1 << 7)
#define GDT_ACCESS_RING0      (0 << 5)
#define GDT_ACCESS_RING3      (3 << 5)
#define GDT_ACCESS_SEGMENT    (1 << 4)
#define GDT_ACCESS_EXEC       (1 << 3)
#define GDT_ACCESS_DC         (1 << 2)
#define GDT_ACCESS_RW         (1 << 1)
#define GDT_ACCESS_ACCESSED   (1 << 0)

/* Granularity byte flags */
#define GDT_GRAN_4K   (1 << 7)
#define GDT_GRAN_32   (1 << 6)
#define GDT_GRAN_64   (1 << 5)

/* A single GDT entry (segment descriptor) — 8 bytes */
typedef struct __attribute__((packed)) {
    uint16_t limit_low;
    uint16_t base_low;
    uint8_t  base_mid;
    uint8_t  access;
    uint8_t  gran;          /* upper nibble: flags, lower nibble: limit_high */
    uint8_t  base_high;
} gdt_entry_t;

/* GDTR — the register loaded by lgdt */
typedef struct __attribute__((packed)) {
    uint16_t limit;
    uint32_t base;
} gdt_descriptor_t;

void gdt_init(void);

#endif /* GDT_H */
