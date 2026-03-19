/* ============================================================
   KSDOS Kernel Linker Script — ELF32, Multiboot-compatible
   Reference: https://wiki.osdev.org/Bare_Bones#Linking_the_Kernel
   ============================================================ */

ENTRY(_start)

SECTIONS {
    /*
     * Kernel loaded at 1 MiB (0x00100000) — safe zone above BIOS data,
     * IVT and EBDA.  This is the canonical higher-half-ready load address
     * recommended by the OSDev community.
     */
    . = 1M;

    /*
     * .multiboot must be within the first 8 KiB of the kernel binary
     * so that GRUB / QEMU can find the Multiboot magic.
     */
    .multiboot ALIGN(4) : {
        *(.multiboot)
    }

    /* Executable code */
    .text ALIGN(4096) : {
        *(.text.early)    /* entry point comes first */
        *(.text*)
    }

    /* Read-only data (strings, const tables, …) */
    .rodata ALIGN(4096) : {
        *(.rodata*)
    }

    /* Initialised read/write data */
    .data ALIGN(4096) : {
        *(.data*)
    }

    /*
     * Uninitialised data (BSS) — zeroed by the bootloader when it
     * honours the Multiboot "memory info" flag.  The kernel also
     * zeroes it manually during early init for safety.
     */
    .bss ALIGN(4096) : {
        *(COMMON)
        *(.bss*)
    }
}
