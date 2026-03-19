/* ============================================================
   GDT - Global Descriptor Table implementation
   Reference: https://wiki.osdev.org/Global_Descriptor_Table
              https://wiki.osdev.org/GDT_Tutorial
   ============================================================ */

#include "gdt.h"

/* 5 descriptors: null, kernel code, kernel data, user code, user data */
#define GDT_ENTRIES 5

static gdt_entry_t      gdt[GDT_ENTRIES];
static gdt_descriptor_t gdtr;

/* Flush the GDT and reload segment registers.
   Defined in gdt_flush.s (inline asm fallback below). */
static void gdt_flush(void) {
    __asm__ volatile (
        "lgdt (%0)\n\t"
        /* Far jump to reload CS with kernel code selector */
        "ljmp %1, $1f\n\t"
        "1:\n\t"
        /* Reload all data segment registers */
        "mov %2, %%ax\n\t"
        "mov %%ax, %%ds\n\t"
        "mov %%ax, %%es\n\t"
        "mov %%ax, %%fs\n\t"
        "mov %%ax, %%gs\n\t"
        "mov %%ax, %%ss\n\t"
        :
        : "r"(&gdtr),
          "i"(GDT_KERNEL_CODE),
          "i"(GDT_KERNEL_DATA)
        : "eax", "memory"
    );
}

/* Build a single GDT entry */
static void gdt_set_entry(int idx,
                          uint32_t base,
                          uint32_t limit,
                          uint8_t  access,
                          uint8_t  gran) {
    gdt[idx].base_low  = (base  & 0xFFFF);
    gdt[idx].base_mid  = (base  >> 16) & 0xFF;
    gdt[idx].base_high = (base  >> 24) & 0xFF;

    gdt[idx].limit_low = (limit & 0xFFFF);
    /* Upper 4 bits of limit + flags packed into gran field */
    gdt[idx].gran = ((limit >> 16) & 0x0F) | (gran & 0xF0);

    gdt[idx].access = access;
}

/* Initialise the GDT with a flat 4 GiB memory model */
void gdt_init(void) {
    gdtr.limit = (sizeof(gdt_entry_t) * GDT_ENTRIES) - 1;
    gdtr.base  = (uint32_t)&gdt;

    /* 0: Null descriptor — required by the CPU spec */
    gdt_set_entry(0, 0, 0, 0, 0);

    /* 1: Kernel code segment — ring 0, executable, readable */
    gdt_set_entry(1,
        0x00000000,
        0xFFFFFFFF,
        GDT_ACCESS_PRESENT | GDT_ACCESS_RING0 |
        GDT_ACCESS_SEGMENT | GDT_ACCESS_EXEC  | GDT_ACCESS_RW,
        GDT_GRAN_4K | GDT_GRAN_32);

    /* 2: Kernel data segment — ring 0, writable */
    gdt_set_entry(2,
        0x00000000,
        0xFFFFFFFF,
        GDT_ACCESS_PRESENT | GDT_ACCESS_RING0 |
        GDT_ACCESS_SEGMENT | GDT_ACCESS_RW,
        GDT_GRAN_4K | GDT_GRAN_32);

    /* 3: User code segment — ring 3, executable, readable */
    gdt_set_entry(3,
        0x00000000,
        0xFFFFFFFF,
        GDT_ACCESS_PRESENT | GDT_ACCESS_RING3 |
        GDT_ACCESS_SEGMENT | GDT_ACCESS_EXEC  | GDT_ACCESS_RW,
        GDT_GRAN_4K | GDT_GRAN_32);

    /* 4: User data segment — ring 3, writable */
    gdt_set_entry(4,
        0x00000000,
        0xFFFFFFFF,
        GDT_ACCESS_PRESENT | GDT_ACCESS_RING3 |
        GDT_ACCESS_SEGMENT | GDT_ACCESS_RW,
        GDT_GRAN_4K | GDT_GRAN_32);

    gdt_flush();
}
