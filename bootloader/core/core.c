/* KSDOS - MS-DOS style kernel
   VGA text mode 80x25 (0xB8000) */

#define VGA_MEM   ((volatile unsigned short *)0xB8000)
#define VGA_COLS  80
#define VGA_ROWS  25

/* VGA attribute bytes (background << 4 | foreground) */
#define ATTR_NORMAL   0x07   /* Light gray on black  */
#define ATTR_BRIGHT   0x0F   /* Bright white on black*/
#define ATTR_YELLOW   0x0E   /* Yellow on black      */
#define ATTR_GREEN    0x0A   /* Light green on black */
#define ATTR_CYAN     0x0B   /* Light cyan on black  */
#define ATTR_RED      0x04   /* Dark red on black    */
#define ATTR_BWHITE   0x70   /* Black on light gray  */

/* ------------------------------------------------------------------ */
/*  Low-level helpers                                                   */
/* ------------------------------------------------------------------ */

static void outb(unsigned short port, unsigned char val)
{
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

static void delay(unsigned int count)
{
    volatile unsigned int i;
    for (i = 0; i < count; i++)
        __asm__ volatile ("nop");
}

/* ------------------------------------------------------------------ */
/*  VGA text-mode driver                                               */
/* ------------------------------------------------------------------ */

static void tty_clear(void)
{
    unsigned int i;
    for (i = 0; i < VGA_COLS * VGA_ROWS; i++)
        VGA_MEM[i] = (unsigned short)(ATTR_NORMAL << 8) | ' ';
}

static void tty_put(int col, int row, char c, unsigned char attr)
{
    if (col < 0 || col >= VGA_COLS || row < 0 || row >= VGA_ROWS)
        return;
    VGA_MEM[row * VGA_COLS + col] = (unsigned short)(attr << 8) | (unsigned char)c;
}

static void tty_puts(int col, int row, const char *s, unsigned char attr)
{
    while (*s)
        tty_put(col++, row, *s++, attr);
}

/* Fill a horizontal segment of cells */
static void tty_fill(int col, int row, int len, char c, unsigned char attr)
{
    int i;
    for (i = 0; i < len; i++)
        tty_put(col + i, row, c, attr);
}

/* Move the hardware blinking cursor */
static void tty_set_cursor(int col, int row)
{
    unsigned short pos = (unsigned short)(row * VGA_COLS + col);
    outb(0x3D4, 0x0F);
    outb(0x3D5, (unsigned char)(pos & 0xFF));
    outb(0x3D4, 0x0E);
    outb(0x3D5, (unsigned char)((pos >> 8) & 0xFF));
}

/* Enable the hardware cursor (scan lines 13-15 = underline) */
static void tty_cursor_enable(void)
{
    outb(0x3D4, 0x0A);
    outb(0x3D5, (unsigned char)((0 & 0xC0) | 13));
    outb(0x3D4, 0x0B);
    outb(0x3D5, (unsigned char)((0 & 0xE0) | 15));
}

/* ------------------------------------------------------------------ */
/*  Simple string length                                               */
/* ------------------------------------------------------------------ */
static int slen(const char *s)
{
    int n = 0;
    while (s[n]) n++;
    return n;
}

/* ------------------------------------------------------------------ */
/*  Draw a centered string on a given row                             */
/* ------------------------------------------------------------------ */
static void tty_puts_center(int row, const char *s, unsigned char attr)
{
    int col = (VGA_COLS - slen(s)) / 2;
    tty_puts(col, row, s, attr);
}

/* ------------------------------------------------------------------ */
/*  Draw the horizontal separator line                                */
/* ------------------------------------------------------------------ */
static void tty_hline(int row, unsigned char attr)
{
    tty_fill(0, row, VGA_COLS, (char)0xCD, attr); /* double-line box char */
}

/* ------------------------------------------------------------------ */
/*  Boot sequence (MS-DOS style scrolling messages)                   */
/* ------------------------------------------------------------------ */
static void boot_sequence(void)
{
    int r = 0;

    /* Starting message */
    tty_puts(0, r++, "Starting KSDOS...", ATTR_NORMAL);
    delay(18000000);

    tty_puts(0, r++, "HIMEM is testing extended memory...", ATTR_NORMAL);
    delay(12000000);

    tty_puts(0, r++, "Loading KSDOS drivers...", ATTR_NORMAL);
    delay(10000000);

    tty_puts(0, r++, "Initializing file system...", ATTR_NORMAL);
    delay(10000000);

    tty_puts(0, r++, "Reading CONFIG.SYS...", ATTR_NORMAL);
    delay(8000000);

    tty_puts(0, r++, "Processing AUTOEXEC.BAT...", ATTR_NORMAL);
    delay(8000000);

    delay(10000000);
}

/* ------------------------------------------------------------------ */
/*  Main desktop (MS-DOS shell)                                        */
/* ------------------------------------------------------------------ */
static void draw_shell(void)
{
    tty_clear();

    /* ---- Header bar ---- */
    tty_fill(0, 0, VGA_COLS, ' ', ATTR_BWHITE);
    tty_puts_center(0, "KSDOS  Version 1.0", ATTR_BWHITE);

    /* ---- Copyright ---- */
    tty_puts(0, 1, "(C)Copyright KSDOS Corp 1994-2026. All rights reserved.", ATTR_NORMAL);

    /* ---- Separator ---- */
    tty_hline(2, ATTR_NORMAL);

    /* ---- Welcome banner ---- */
    tty_puts_center(4, "***  WELCOME BACK TO KSDOS  ***", ATTR_BRIGHT);
    tty_puts_center(5, "The KernelSoft Disk Operating System", ATTR_YELLOW);

    /* ---- Separator ---- */
    tty_hline(7, ATTR_NORMAL);

    /* ---- System info ---- */
    tty_puts(0,  9, "  Memory: 640 KB conventional memory available.", ATTR_NORMAL);
    tty_puts(0, 10, "  Drive C: ready.", ATTR_NORMAL);
    tty_puts(0, 11, "  KSDOS shell v1.0 loaded.", ATTR_NORMAL);

    /* ---- Separator ---- */
    tty_hline(13, ATTR_NORMAL);

    /* ---- Prompt ---- */
    tty_puts(0, 15, "C:\\>", ATTR_NORMAL);

    /* Position blinking hardware cursor right after the prompt */
    tty_set_cursor(4, 15);
}

/* ================================================================== */
/*  Kernel entry point                                                 */
/* ================================================================== */
void core_main(void)
{
    tty_cursor_enable();
    tty_clear();

    /* Show scrolling boot messages */
    boot_sequence();

    /* Render the final MS-DOS style shell */
    draw_shell();

    /* Halt the CPU */
    for (;;)
        __asm__ volatile ("cli; hlt");
}
