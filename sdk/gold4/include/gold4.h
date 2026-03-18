/* GOLD4 SDK - DOOM-era x86 DOS Game Development Kit
   KSDOS Edition - Compatible with DJGPP / Watcom / Open Watcom
   Target: i386-elf bare-metal or DJGPP DOS                        */
#ifndef GOLD4_H
#define GOLD4_H

/* ---- basic types ---- */
typedef unsigned char  byte;
typedef unsigned short word;
typedef unsigned int   dword;
typedef signed   char  sbyte;
typedef signed   short sword;
typedef signed   int   sdword;
typedef unsigned char  boolean;
#define true  1
#define false 0
#define null  ((void *)0)

/* ---- video (VGA Mode 13h - 320x200x256) ---- */
#define VGA_WIDTH  320
#define VGA_HEIGHT 200
#define VGA_COLORS 256
#define VGA_VRAM   ((volatile byte *)0xA0000)
#define VGA_DAC_ADDR  0x3C8
#define VGA_DAC_DATA  0x3C9

static inline void gold4_set_mode13(void) {
    /* Mode 13h: 320x200 256-color */
    __asm__ volatile (
        "movb $0x13, %%al \n"
        "movb $0x00, %%ah \n"
        "int  $0x10       \n"
        : : : "eax"
    );
}
static inline void gold4_set_text(void) {
    __asm__ volatile (
        "movb $0x03, %%al \n"
        "movb $0x00, %%ah \n"
        "int  $0x10       \n"
        : : : "eax"
    );
}

/* ---- palette ---- */
static inline void gold4_set_palette(byte index, byte r, byte g, byte b) {
    /* Write to DAC: values are 0-63 */
    __asm__ volatile ("outb %0, %1" : : "a"(index), "Nd"((word)VGA_DAC_ADDR));
    __asm__ volatile ("outb %0, %1" : : "a"((byte)(r>>2)), "Nd"((word)VGA_DAC_DATA));
    __asm__ volatile ("outb %0, %1" : : "a"((byte)(g>>2)), "Nd"((word)VGA_DAC_DATA));
    __asm__ volatile ("outb %0, %1" : : "a"((byte)(b>>2)), "Nd"((word)VGA_DAC_DATA));
}

/* ---- draw primitives ---- */
static inline void gold4_put_pixel(int x, int y, byte color) {
    if (x >= 0 && x < VGA_WIDTH && y >= 0 && y < VGA_HEIGHT)
        VGA_VRAM[y * VGA_WIDTH + x] = color;
}
static inline void gold4_clear(byte color) {
    dword i;
    for (i = 0; i < (dword)(VGA_WIDTH * VGA_HEIGHT); i++)
        VGA_VRAM[i] = color;
}
static inline void gold4_hline(int y, int x0, int x1, byte color) {
    int x;
    for (x = x0; x <= x1; x++) gold4_put_pixel(x, y, color);
}
static inline void gold4_vline(int x, int y0, int y1, byte color) {
    int y;
    for (y = y0; y <= y1; y++) gold4_put_pixel(x, y, color);
}
static inline void gold4_rect(int x, int y, int w, int h, byte color) {
    gold4_hline(y,     x, x+w-1, color);
    gold4_hline(y+h-1, x, x+w-1, color);
    gold4_vline(x,     y, y+h-1, color);
    gold4_vline(x+w-1, y, y+h-1, color);
}
static inline void gold4_fill_rect(int x, int y, int w, int h, byte color) {
    int yy;
    for (yy = y; yy < y+h; yy++) gold4_hline(yy, x, x+w-1, color);
}

/* ---- WAD file format ---- */
#define WAD_MAGIC_IWAD 0x44415749  /* "IWAD" */
#define WAD_MAGIC_PWAD 0x44415750  /* "PWAD" */

typedef struct {
    dword magic;
    dword numlumps;
    dword infotableofs;
} WadHeader;

typedef struct {
    dword filepos;
    dword size;
    char  name[8];
} WadLump;

/* ---- map / BSP ---- */
typedef struct {
    sword x, y;
} MapVertex;

typedef struct {
    sword x, y, dx, dy;
    sword right_sidedef;
    sword left_sidedef;
} MapLineDef;

typedef struct {
    word  v1, v2;
    word  flags;
    word  special;
    word  tag;
    word  sidenum[2];
} Linedef;

/* ---- thing (entity) ---- */
typedef struct {
    sword x, y;
    sword angle;
    word  type;
    word  flags;
} MapThing;

/* ---- fixed-point (16.16) ---- */
typedef sdword fixed_t;
#define FRACBITS  16
#define FRACUNIT  (1<<FRACBITS)
#define FIX(x)    ((fixed_t)((x)*FRACUNIT))
#define FIXMUL(a,b) (((long long)(a)*(b))>>FRACBITS)
#define FIXDIV(a,b) (((long long)(a)<<FRACBITS)/(b))

/* ---- trig (360-entry table, scaled to FRACUNIT) ---- */
extern fixed_t sin_table[361];
extern fixed_t cos_table[361];

/* ---- input (keyboard scan codes) ---- */
#define KEY_ESC      0x01
#define KEY_ENTER    0x1C
#define KEY_SPACE    0x39
#define KEY_UP_ARROW 0x48
#define KEY_DN_ARROW 0x50
#define KEY_LT_ARROW 0x4B
#define KEY_RT_ARROW 0x4D
#define KEY_CTRL     0x1D
#define KEY_ALT      0x38
#define KEY_A  0x1E
#define KEY_D  0x20
#define KEY_E  0x12
#define KEY_S  0x1F
#define KEY_W  0x11

static inline byte gold4_getkey(void) {
    byte key = 0;
    __asm__ volatile (
        "inb $0x60, %0" : "=a"(key)
    );
    return key;
}

/* ---- sound (PC speaker) ---- */
static inline void gold4_beep(word freq) {
    word div = (word)(1193180UL / (dword)freq);
    byte v;
    /* Timer 2 */
    __asm__ volatile ("outb %0, %1" : : "a"((byte)0xB6), "Nd"((word)0x43));
    __asm__ volatile ("outb %0, %1" : : "a"((byte)(div & 0xFF)), "Nd"((word)0x42));
    __asm__ volatile ("outb %0, %1" : : "a"((byte)(div >> 8)),   "Nd"((word)0x42));
    __asm__ volatile ("inb %1, %0"  : "=a"(v) : "Nd"((word)0x61));
    v |= 3;
    __asm__ volatile ("outb %0, %1" : : "a"(v), "Nd"((word)0x61));
}
static inline void gold4_nosound(void) {
    byte v;
    __asm__ volatile ("inb %1, %0"  : "=a"(v) : "Nd"((word)0x61));
    v &= ~3;
    __asm__ volatile ("outb %0, %1" : : "a"(v), "Nd"((word)0x61));
}

/* ---- linker script symbol (for WAD embedding) ---- */
extern char _wad_start[];
extern char _wad_end[];

#endif /* GOLD4_H */
