/* PSYq SDK - PlayStation 1 Development Kit
   KSDOS Edition - Portable stub for host-side development
   Targets: mipsel-linux-gnu-gcc (bare-metal PS1)             */
#ifndef LIBPS_H
#define LIBPS_H

/* ---- basic types ---- */
typedef unsigned char  u_char;
typedef unsigned short u_short;
typedef unsigned int   u_int;
typedef unsigned long  u_long;
typedef signed   char  s_char;
typedef signed   short s_short;
typedef signed   int   s_int;
typedef signed   long  s_long;

/* ---- PS1 hardware base addresses ---- */
#define PS1_GPU_GP0   0x1F801810  /* GPU data / command port */
#define PS1_GPU_GP1   0x1F801814  /* GPU control / status    */
#define PS1_SPU_BASE  0x1F801C00  /* SPU base                */
#define PS1_TIMER0    0x1F801100  /* Timer 0 (root counter)  */
#define PS1_JOY_STAT  0x1F801044  /* Controller status       */
#define PS1_JOY_DATA  0x1F801040  /* Controller data         */
#define PS1_VRAM      0x00000000  /* VRAM (1MB, GPU managed) */
#define MMIO(addr)    (*(volatile u_int *)(addr))

/* ---- BIOS syscalls (vectored through 0xA0/0xB0/0xC0) ---- */
static inline void psyq_puts(const char *s) {
    while (*s) {
        volatile int dummy = *s++;
        (void)dummy;
    }
}

/* ---- GPU command helpers ---- */
#define GPU_CMD_CLEAR_VRAM  0x02
#define GPU_CMD_FILL_RECT   0x02
#define GPU_CMD_DRAW_POLY_F3 0x20  /* flat-shaded triangle */
#define GPU_CMD_DRAW_POLY_G3 0x30  /* gouraud-shaded triangle */
#define GPU_CMD_DRAW_RECT   0x60

typedef struct {
    u_int cmd;       /* command + colour (BGR) */
    u_int xy;        /* (y<<16)|x             */
    u_int wh;        /* (h<<16)|w             */
} GPU_Rect;

typedef struct {
    u_int  cmd;      /* 0x20 | colour */
    u_int  v0xy;     /* vertex 0 (y<<16|x) */
    u_int  v1xy;     /* vertex 1           */
    u_int  v2xy;     /* vertex 2           */
} GPU_Poly_F3;

/* ---- Pad / controller ---- */
#define PAD_SELECT  0x0001
#define PAD_L3      0x0002
#define PAD_R3      0x0004
#define PAD_START   0x0008
#define PAD_UP      0x0010
#define PAD_RIGHT   0x0020
#define PAD_DOWN    0x0040
#define PAD_LEFT    0x0080
#define PAD_L2      0x0100
#define PAD_R2      0x0200
#define PAD_L1      0x0400
#define PAD_R1      0x0800
#define PAD_TRIANGLE 0x1000
#define PAD_CIRCLE   0x2000
#define PAD_CROSS    0x4000
#define PAD_SQUARE   0x8000

/* ---- GTE (Geometry Transform Engine) macros ---- */
typedef struct { s_short vx, vy, vz, pad; } SVECTOR;
typedef struct { s_long  vx, vy, vz, pad; } VECTOR;
typedef struct { s_short m[3][3]; s_short pad; } MATRIX;

#define gte_ldv0(v)   __asm__ volatile ("ctc2 %0,$0" : : "r"(v))
#define gte_rtps()    __asm__ volatile ("cop2 0x0180001")
#define gte_stxy0(xy) __asm__ volatile ("mfc2 %0,$14" : "=r"(xy))

/* ---- Memory card ---- */
#define MEMCARD_MAGIC 0x4D43  /* "MC" */

/* ---- CD-ROM ---- */
typedef struct {
    u_char  minute;
    u_char  second;
    u_char  sector;
    u_char  mode;
} CdlLOC;

/* ---- Primitive ordering table ---- */
typedef struct OT_tag {
    u_int   tag;
} OT_tag;

#define OTLEN 256

static inline void psyq_ot_clear(OT_tag *ot, int n) {
    int i;
    for (i = 0; i < n; i++)
        ot[i].tag = (u_int)(unsigned long)(&ot[i > 0 ? i-1 : 0]);
}

/* ---- Fixed-point maths ---- */
#define ONE         4096
#define FP(x)       ((s_long)((x)*ONE))
#define FP_MUL(a,b) (((s_long)(a)*(s_long)(b))>>12)

/* ---- Video / display ---- */
#define VMODE_NTSC 0
#define VMODE_PAL  1

typedef struct {
    int x, y, w, h;
} RECT;

typedef struct {
    RECT disp;     /* display area in VRAM */
    RECT draw;     /* draw area in VRAM    */
    int  mode;     /* NTSC / PAL           */
} DISPENV;

/* ---- Init / vsync ---- */
static inline void psyq_ResetGraph(int mode) { (void)mode; }
static inline void psyq_VSync(int n)          { (void)n;    }
static inline void psyq_DrawSync(int n)       { (void)n;    }

#endif /* LIBPS_H */
