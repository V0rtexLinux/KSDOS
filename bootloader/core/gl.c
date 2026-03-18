/* KSDOS - Software OpenGL renderer (Bochs VBE, 32-bit protected mode)
   640x480 32bpp linear framebuffer at 0xE0000000
   Fixed-point 3D: cube, PSX-style, DOOM-style raycaster               */

#include "gl.h"

/* ------------------------------------------------------------------ */
/*  Low-level I/O (mirrored from core.c — declared static inline)     */
/* ------------------------------------------------------------------ */
static inline void outb(unsigned short port, unsigned char val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}
static inline unsigned char inb(unsigned short port) {
    unsigned char ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}
static inline void outw(unsigned short port, unsigned short val) {
    __asm__ volatile ("outw %0, %1" : : "a"(val), "Nd"(port));
}

/* ------------------------------------------------------------------ */
/*  Bochs VBE helpers                                                  */
/* ------------------------------------------------------------------ */
static void vbe_write(unsigned short idx, unsigned short val) {
    outw(VBE_DISPI_IOPORT_INDEX, idx);
    outw(VBE_DISPI_IOPORT_DATA,  val);
}

void gl_init(void) {
    vbe_write(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_DISABLED);
    vbe_write(VBE_DISPI_INDEX_XRES,   GL_WIDTH);
    vbe_write(VBE_DISPI_INDEX_YRES,   GL_HEIGHT);
    vbe_write(VBE_DISPI_INDEX_BPP,    GL_BPP);
    vbe_write(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_ENABLED | VBE_DISPI_LFB_ENABLED);
}

void gl_shutdown(void) {
    vbe_write(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_DISABLED);
    /* Restore VGA text mode via I/O registers */
    outb(0x3C2, 0x67);          /* misc output */
    outb(0x3D4, 0x00); outb(0x3D5, 0x5F);  /* h total */
    outb(0x3D4, 0x01); outb(0x3D5, 0x4F);  /* h display end */
    outb(0x3D4, 0x02); outb(0x3D5, 0x50);  /* h blank start */
    outb(0x3D4, 0x03); outb(0x3D5, 0x82);  /* h blank end */
    outb(0x3D4, 0x04); outb(0x3D5, 0x55);  /* h retrace start */
    outb(0x3D4, 0x05); outb(0x3D5, 0x81);  /* h retrace end */
}

/* ------------------------------------------------------------------ */
/*  Framebuffer primitives                                             */
/* ------------------------------------------------------------------ */
void gl_clear(unsigned int color) {
    unsigned int i;
    volatile unsigned int *fb = GL_FB;
    for (i = 0; i < GL_WIDTH * GL_HEIGHT; i++)
        fb[i] = color;
}

void gl_put_pixel(int x, int y, unsigned int color) {
    if (x < 0 || x >= GL_WIDTH || y < 0 || y >= GL_HEIGHT) return;
    GL_FB[y * GL_WIDTH + x] = color;
}

void gl_line(int x0, int y0, int x1, int y1, unsigned int color) {
    int dx = x1 - x0;  if (dx < 0) dx = -dx;
    int dy = y1 - y0;  if (dy < 0) dy = -dy;
    int sx = (x0 < x1) ? 1 : -1;
    int sy = (y0 < y1) ? 1 : -1;
    int err = dx - dy;
    while (1) {
        gl_put_pixel(x0, y0, color);
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x0 += sx; }
        if (e2 <  dx) { err += dx; y0 += sy; }
    }
}

/* Flat-shaded triangle (bottom-flat + top-flat decomposition) */
static void fill_flat_bottom(int x0,int y0,int x1,int y1,int x2,int y2, unsigned int c) {
    int dy = y2 - y0;  if (dy == 0) return;
    int i;
    for (i = 0; i <= (y2-y0); i++) {
        int xa = x0 + (x1 - x0) * i / dy;
        int xb = x0 + (x2 - x0) * i / dy;
        int y  = y0 + i;
        if (xa > xb) { int t = xa; xa = xb; xb = t; }
        int xi;
        for (xi = xa; xi <= xb; xi++) gl_put_pixel(xi, y, c);
    }
}
static void fill_flat_top(int x0,int y0,int x1,int y1,int x2,int y2, unsigned int c) {
    int dy = y2 - y0;  if (dy == 0) return;
    int i;
    for (i = 0; i <= (y2-y0); i++) {
        int xa = x0 + (x2 - x0) * i / dy;
        int xb = x1 + (x2 - x1) * i / dy;
        int y  = y0 + i;
        if (xa > xb) { int t = xa; xa = xb; xb = t; }
        int xi;
        for (xi = xa; xi <= xb; xi++) gl_put_pixel(xi, y, c);
    }
}

/* Sort vertices by y then rasterise */
void gl_fill_triangle(int x0,int y0,int x1,int y1,int x2,int y2, unsigned int color) {
    /* Bubble-sort by y */
    int tx, ty;
#define SWAP(ax,ay,bx,by) tx=ax;ty=ay;ax=bx;ay=by;bx=tx;by=ty
    if (y0 > y1) { SWAP(x0,y0,x1,y1); }
    if (y0 > y2) { SWAP(x0,y0,x2,y2); }
    if (y1 > y2) { SWAP(x1,y1,x2,y2); }
#undef SWAP
    if (y1 == y2) {
        fill_flat_bottom(x0,y0,x1,y1,x2,y2, color);
    } else if (y0 == y1) {
        fill_flat_top(x0,y0,x1,y1,x2,y2, color);
    } else {
        /* Split triangle at midpoint */
        int dy = y2 - y0;  if (dy == 0) return;
        int mx = x0 + (x2 - x0) * (y1 - y0) / dy;
        int my = y1;
        fill_flat_bottom(x0,y0, x1,y1, mx,my, color);
        fill_flat_top(x1,y1, mx,my, x2,y2, color);
    }
}

/* ------------------------------------------------------------------ */
/*  Tiny bitmap font (5x7 per glyph, ASCII 32-127)                    */
/* ------------------------------------------------------------------ */
static const unsigned char font5x7[96][5] = {
    {0x00,0x00,0x00,0x00,0x00}, /* 32 SPACE  */
    {0x00,0x00,0x5F,0x00,0x00}, /* 33 !      */
    {0x00,0x07,0x00,0x07,0x00}, /* 34 "      */
    {0x14,0x7F,0x14,0x7F,0x14}, /* 35 #      */
    {0x24,0x2A,0x7F,0x2A,0x12}, /* 36 $      */
    {0x23,0x13,0x08,0x64,0x62}, /* 37 %      */
    {0x36,0x49,0x55,0x22,0x50}, /* 38 &      */
    {0x00,0x05,0x03,0x00,0x00}, /* 39 '      */
    {0x00,0x1C,0x22,0x41,0x00}, /* 40 (      */
    {0x00,0x41,0x22,0x1C,0x00}, /* 41 )      */
    {0x14,0x08,0x3E,0x08,0x14}, /* 42 *      */
    {0x08,0x08,0x3E,0x08,0x08}, /* 43 +      */
    {0x00,0x50,0x30,0x00,0x00}, /* 44 ,      */
    {0x08,0x08,0x08,0x08,0x08}, /* 45 -      */
    {0x00,0x60,0x60,0x00,0x00}, /* 46 .      */
    {0x20,0x10,0x08,0x04,0x02}, /* 47 /      */
    {0x3E,0x51,0x49,0x45,0x3E}, /* 48 0      */
    {0x00,0x42,0x7F,0x40,0x00}, /* 49 1      */
    {0x42,0x61,0x51,0x49,0x46}, /* 50 2      */
    {0x21,0x41,0x45,0x4B,0x31}, /* 51 3      */
    {0x18,0x14,0x12,0x7F,0x10}, /* 52 4      */
    {0x27,0x45,0x45,0x45,0x39}, /* 53 5      */
    {0x3C,0x4A,0x49,0x49,0x30}, /* 54 6      */
    {0x01,0x71,0x09,0x05,0x03}, /* 55 7      */
    {0x36,0x49,0x49,0x49,0x36}, /* 56 8      */
    {0x06,0x49,0x49,0x29,0x1E}, /* 57 9      */
    {0x00,0x36,0x36,0x00,0x00}, /* 58 :      */
    {0x00,0x56,0x36,0x00,0x00}, /* 59 ;      */
    {0x08,0x14,0x22,0x41,0x00}, /* 60 <      */
    {0x14,0x14,0x14,0x14,0x14}, /* 61 =      */
    {0x00,0x41,0x22,0x14,0x08}, /* 62 >      */
    {0x02,0x01,0x51,0x09,0x06}, /* 63 ?      */
    {0x32,0x49,0x79,0x41,0x3E}, /* 64 @      */
    {0x7E,0x11,0x11,0x11,0x7E}, /* 65 A      */
    {0x7F,0x49,0x49,0x49,0x36}, /* 66 B      */
    {0x3E,0x41,0x41,0x41,0x22}, /* 67 C      */
    {0x7F,0x41,0x41,0x22,0x1C}, /* 68 D      */
    {0x7F,0x49,0x49,0x49,0x41}, /* 69 E      */
    {0x7F,0x09,0x09,0x09,0x01}, /* 70 F      */
    {0x3E,0x41,0x49,0x49,0x7A}, /* 71 G      */
    {0x7F,0x08,0x08,0x08,0x7F}, /* 72 H      */
    {0x00,0x41,0x7F,0x41,0x00}, /* 73 I      */
    {0x20,0x40,0x41,0x3F,0x01}, /* 74 J      */
    {0x7F,0x08,0x14,0x22,0x41}, /* 75 K      */
    {0x7F,0x40,0x40,0x40,0x40}, /* 76 L      */
    {0x7F,0x02,0x0C,0x02,0x7F}, /* 77 M      */
    {0x7F,0x04,0x08,0x10,0x7F}, /* 78 N      */
    {0x3E,0x41,0x41,0x41,0x3E}, /* 79 O      */
    {0x7F,0x09,0x09,0x09,0x06}, /* 80 P      */
    {0x3E,0x41,0x51,0x21,0x5E}, /* 81 Q      */
    {0x7F,0x09,0x19,0x29,0x46}, /* 82 R      */
    {0x46,0x49,0x49,0x49,0x31}, /* 83 S      */
    {0x01,0x01,0x7F,0x01,0x01}, /* 84 T      */
    {0x3F,0x40,0x40,0x40,0x3F}, /* 85 U      */
    {0x1F,0x20,0x40,0x20,0x1F}, /* 86 V      */
    {0x3F,0x40,0x38,0x40,0x3F}, /* 87 W      */
    {0x63,0x14,0x08,0x14,0x63}, /* 88 X      */
    {0x07,0x08,0x70,0x08,0x07}, /* 89 Y      */
    {0x61,0x51,0x49,0x45,0x43}, /* 90 Z      */
    {0x00,0x7F,0x41,0x41,0x00}, /* 91 [      */
    {0x02,0x04,0x08,0x10,0x20}, /* 92 \      */
    {0x00,0x41,0x41,0x7F,0x00}, /* 93 ]      */
    {0x04,0x02,0x01,0x02,0x04}, /* 94 ^      */
    {0x40,0x40,0x40,0x40,0x40}, /* 95 _      */
    {0x00,0x01,0x02,0x04,0x00}, /* 96 `      */
    {0x20,0x54,0x54,0x54,0x78}, /* 97 a      */
    {0x7F,0x48,0x44,0x44,0x38}, /* 98 b      */
    {0x38,0x44,0x44,0x44,0x20}, /* 99 c      */
    {0x38,0x44,0x44,0x48,0x7F}, /* 100 d     */
    {0x38,0x54,0x54,0x54,0x18}, /* 101 e     */
    {0x08,0x7E,0x09,0x01,0x02}, /* 102 f     */
    {0x0C,0x52,0x52,0x52,0x3E}, /* 103 g     */
    {0x7F,0x08,0x04,0x04,0x78}, /* 104 h     */
    {0x00,0x44,0x7D,0x40,0x00}, /* 105 i     */
    {0x20,0x40,0x44,0x3D,0x00}, /* 106 j     */
    {0x7F,0x10,0x28,0x44,0x00}, /* 107 k     */
    {0x00,0x41,0x7F,0x40,0x00}, /* 108 l     */
    {0x7C,0x04,0x18,0x04,0x78}, /* 109 m     */
    {0x7C,0x08,0x04,0x04,0x78}, /* 110 n     */
    {0x38,0x44,0x44,0x44,0x38}, /* 111 o     */
    {0x7C,0x14,0x14,0x14,0x08}, /* 112 p     */
    {0x08,0x14,0x14,0x18,0x7C}, /* 113 q     */
    {0x7C,0x08,0x04,0x04,0x08}, /* 114 r     */
    {0x48,0x54,0x54,0x54,0x20}, /* 115 s     */
    {0x04,0x3F,0x44,0x40,0x20}, /* 116 t     */
    {0x3C,0x40,0x40,0x20,0x7C}, /* 117 u     */
    {0x1C,0x20,0x40,0x20,0x1C}, /* 118 v     */
    {0x3C,0x40,0x30,0x40,0x3C}, /* 119 w     */
    {0x44,0x28,0x10,0x28,0x44}, /* 120 x     */
    {0x0C,0x50,0x50,0x50,0x3C}, /* 121 y     */
    {0x44,0x64,0x54,0x4C,0x44}, /* 122 z     */
    {0x00,0x08,0x36,0x41,0x00}, /* 123 {     */
    {0x00,0x00,0x7F,0x00,0x00}, /* 124 |     */
    {0x00,0x41,0x36,0x08,0x00}, /* 125 }     */
    {0x10,0x08,0x08,0x10,0x08}, /* 126 ~     */
    {0x7E,0x5D,0x5D,0x7E,0x00}, /* 127 DEL   */
};

void gl_text(int x, int y, const char *s, unsigned int fg, unsigned int bg) {
    while (*s) {
        unsigned char ch = (unsigned char)*s;
        if (ch >= 32 && ch <= 127) {
            const unsigned char *glyph = font5x7[ch - 32];
            int cx, cy;
            for (cx = 0; cx < 5; cx++) {
                for (cy = 0; cy < 7; cy++) {
                    unsigned int c = (glyph[cx] & (1 << cy)) ? fg : bg;
                    gl_put_pixel(x + cx, y + cy, c);
                }
            }
        }
        x += 6;
        s++;
    }
}

/* ------------------------------------------------------------------ */
/*  Fixed-point maths (16.16)                                          */
/* ------------------------------------------------------------------ */
typedef int fixed_t;
#define FX(v)       ((fixed_t)((v) * 65536))
#define FX_MUL(a,b) ((fixed_t)(((long long)(a) * (b)) >> 16))

/* Sine table (90 entries, quarter circle, scaled to FX(1.0)) */
static const fixed_t sin_tbl[91] = {
    0,1144,2287,3430,4572,5712,6850,7986,9120,10251,
    11380,12505,13626,14742,15854,16962,18064,19161,20252,21336,
    22415,23486,24551,25607,26656,27697,28729,29752,30767,31772,
    32768,33754,34730,35696,36650,37594,38526,39448,40358,41256,
    42142,43016,43878,44727,45563,46386,47195,47991,48773,49541,
    50296,51036,51762,52473,53170,53852,54520,55173,55811,56434,
    57042,57635,58213,58775,59322,59854,60370,60871,61356,61826,
    62279,62717,63139,63545,63935,64310,64668,69010,65326,65526,
    65536,65526,65510,65478,65430,65366,65287,65193,65083,64958,
    64818
};

static fixed_t fx_sin(int deg) {
    deg = ((deg % 360) + 360) % 360;
    if (deg <= 90)  return  sin_tbl[deg];
    if (deg <= 180) return  sin_tbl[180 - deg];
    if (deg <= 270) return -sin_tbl[deg - 180];
    return                 -sin_tbl[360 - deg];
}
static fixed_t fx_cos(int deg) { return fx_sin(deg + 90); }

/* ------------------------------------------------------------------ */
/*  3D Cube vertices (8 corners, +-64 units)                           */
/* ------------------------------------------------------------------ */
static const fixed_t cube_v[8][3] = {
    {FX(-64), FX(-64), FX(-64)},
    {FX( 64), FX(-64), FX(-64)},
    {FX( 64), FX( 64), FX(-64)},
    {FX(-64), FX( 64), FX(-64)},
    {FX(-64), FX(-64), FX( 64)},
    {FX( 64), FX(-64), FX( 64)},
    {FX( 64), FX( 64), FX( 64)},
    {FX(-64), FX( 64), FX( 64)},
};

/* 6 faces (each as 2 triangles), with colour */
static const int cube_faces[6][4] = {
    {0,1,2,3}, /* back   */
    {4,5,6,7}, /* front  */
    {0,1,5,4}, /* bottom */
    {2,3,7,6}, /* top    */
    {0,3,7,4}, /* left   */
    {1,2,6,5}, /* right  */
};
static const unsigned int face_colors[6] = {
    GL_RED, GL_GREEN, GL_BLUE, GL_YELLOW, GL_CYAN, GL_MAGENTA
};

/* Rotate a vertex by (rx,ry,rz) degrees, result in px,py */
static void rotate_project(const fixed_t v[3], int rx, int ry, int rz,
                            int *px, int *py)
{
    fixed_t x = v[0], y = v[1], z = v[2];
    fixed_t t;
    /* X rotation */
    t = FX_MUL(fx_cos(rx), y) - FX_MUL(fx_sin(rx), z);
    z = FX_MUL(fx_sin(rx), y) + FX_MUL(fx_cos(rx), z);
    y = t;
    /* Y rotation */
    t = FX_MUL(fx_cos(ry), x) + FX_MUL(fx_sin(ry), z);
    z =-FX_MUL(fx_sin(ry), x) + FX_MUL(fx_cos(ry), z);
    x = t;
    /* Z rotation */
    t = FX_MUL(fx_cos(rz), x) - FX_MUL(fx_sin(rz), y);
    y = FX_MUL(fx_sin(rz), x) + FX_MUL(fx_cos(rz), y);
    x = t;
    /* Perspective: camera at z=300 */
    fixed_t fz = z + FX(300);
    if (fz < FX(1)) fz = FX(1);
    *px = GL_WIDTH/2  + (int)(FX_MUL(x, FX(256)) / (fz >> 16));
    *py = GL_HEIGHT/2 + (int)(FX_MUL(y, FX(256)) / (fz >> 16));
}

static void delay_gl(unsigned int n) {
    volatile unsigned int i;
    for (i = 0; i < n; i++) __asm__ volatile ("nop");
}

/* ------------------------------------------------------------------ */
/*  Demo: rotating RGB cube                                            */
/* ------------------------------------------------------------------ */
void gl_demo_cube(void) {
    gl_init();
    int frame;
    for (frame = 0; frame < 200; frame++) {
        int rx = frame * 2;
        int ry = frame * 3;
        int rz = frame;

        gl_clear(GL_RGB(10,10,30));

        /* Draw title */
        gl_text(180, 10, "KSDOS OpenGL - Rotating Cube", GL_WHITE, GL_RGB(10,10,30));
        gl_text(210, 22, "Press any key to exit", GL_RGB(180,180,180), GL_RGB(10,10,30));

        /* Project all 8 vertices */
        int px[8], py[8];
        int i;
        for (i = 0; i < 8; i++)
            rotate_project(cube_v[i], rx, ry, rz, &px[i], &py[i]);

        /* Draw each face as 2 triangles */
        int f;
        for (f = 0; f < 6; f++) {
            const int *fi = cube_faces[f];
            unsigned int col = face_colors[f];
            /* Shade: darken based on face index */
            unsigned int r = (col >> 16) & 0xFF;
            unsigned int g = (col >>  8) & 0xFF;
            unsigned int b =  col        & 0xFF;
            unsigned int shade = (unsigned int)(160 + (f * 12));
            r = r * shade / 255;
            g = g * shade / 255;
            b = b * shade / 255;
            col = GL_RGB(r, g, b);
            gl_fill_triangle(px[fi[0]],py[fi[0]], px[fi[1]],py[fi[1]], px[fi[2]],py[fi[2]], col);
            gl_fill_triangle(px[fi[0]],py[fi[0]], px[fi[2]],py[fi[2]], px[fi[3]],py[fi[3]], col);
            /* Wireframe edges */
            unsigned int ecol = GL_RGB(r+40>255?255:r+40, g+40>255?255:g+40, b+40>255?255:b+40);
            gl_line(px[fi[0]],py[fi[0]], px[fi[1]],py[fi[1]], ecol);
            gl_line(px[fi[1]],py[fi[1]], px[fi[2]],py[fi[2]], ecol);
            gl_line(px[fi[2]],py[fi[2]], px[fi[3]],py[fi[3]], ecol);
            gl_line(px[fi[3]],py[fi[3]], px[fi[0]],py[fi[0]], ecol);
        }

        delay_gl(2000000);

        /* Check for keypress: port 0x64 status bit 0 */
        if (inb(0x64) & 1) break;
    }
    gl_shutdown();
}

/* ------------------------------------------------------------------ */
/*  Demo: PSX-style flat-shaded scene                                  */
/* ------------------------------------------------------------------ */
void gl_demo_psx(void) {
    gl_init();
    int frame;
    for (frame = 0; frame < 180; frame++) {
        /* Sky gradient */
        int y;
        for (y = 0; y < GL_HEIGHT/2; y++) {
            unsigned int sky_r = 20 + y/4;
            unsigned int sky_b = 80 + y/3;
            int x;
            for (x = 0; x < GL_WIDTH; x++)
                GL_FB[y * GL_WIDTH + x] = GL_RGB(sky_r, 10, sky_b);
        }
        /* Ground */
        for (y = GL_HEIGHT/2; y < GL_HEIGHT; y++) {
            unsigned int g = 30 + (y - GL_HEIGHT/2)/6;
            int x;
            for (x = 0; x < GL_WIDTH; x++)
                GL_FB[y * GL_WIDTH + x] = GL_RGB(g, g+10, g/2);
        }

        /* PSX logo wireframe quad, rotated */
        int cx = GL_WIDTH/2, cy = GL_HEIGHT/2;
        int r  = 80 + FX_MUL(fx_sin(frame*3), FX(20)) / 65536;
        int a  = frame * 2;
        int x0 = cx + r * fx_cos(a)         / 65536;
        int y0 = cy + r * fx_sin(a)         / 65536;
        int x1 = cx + r * fx_cos(a + 90)    / 65536;
        int y1 = cy + r * fx_sin(a + 90)    / 65536;
        int x2 = cx + r * fx_cos(a + 180)   / 65536;
        int y2 = cy + r * fx_sin(a + 180)   / 65536;
        int x3 = cx + r * fx_cos(a + 270)   / 65536;
        int y3 = cy + r * fx_sin(a + 270)   / 65536;

        gl_fill_triangle(x0,y0, x1,y1, x2,y2, GL_RGB(180,20,20));
        gl_fill_triangle(x0,y0, x2,y2, x3,y3, GL_RGB(20,20,180));

        gl_line(x0,y0, x1,y1, GL_WHITE);
        gl_line(x1,y1, x2,y2, GL_WHITE);
        gl_line(x2,y2, x3,y3, GL_WHITE);
        gl_line(x3,y3, x0,y0, GL_WHITE);

        gl_text(200, 30, "KSDOS PSX Dev - psyq SDK", GL_YELLOW, 0);
        gl_text(220, 44, "PlayStation(R) Style Demo", GL_WHITE,  0);

        delay_gl(1500000);
        if (inb(0x64) & 1) break;
    }
    gl_shutdown();
}

/* ------------------------------------------------------------------ */
/*  Demo: DOOM-style raycaster                                         */
/* ------------------------------------------------------------------ */
#define MAP_W 16
#define MAP_H 16
static const unsigned char dmap[MAP_H][MAP_W] = {
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,1,0,1,1,1,0,0,1,1,0,0,1,0,1},
    {1,0,1,0,0,0,1,0,0,1,0,0,0,1,0,1},
    {1,0,1,1,1,0,1,0,0,0,0,1,1,1,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,1,0,1,1,0,1,1,0,1,1,0,1,0,1},
    {1,0,0,0,1,0,0,0,0,0,0,1,0,0,0,1},
    {1,0,0,0,1,0,0,1,1,0,0,1,0,0,0,1},
    {1,0,1,0,0,0,0,0,0,0,0,0,0,1,0,1},
    {1,0,1,1,0,1,1,0,0,1,1,0,1,1,0,1},
    {1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1},
    {1,0,1,0,1,0,0,0,0,0,0,1,0,1,0,1},
    {1,0,1,1,1,1,1,0,0,1,1,1,1,1,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
};

void gl_demo_doom(void) {
    gl_init();

    /* Player position and angle (fixed point) */
    fixed_t px = FX(8), py = FX(8);
    int angle = 0;

    int frame;
    for (frame = 0; frame < 300; frame++) {
        angle = (angle + 1) % 360;

        /* Sky */
        int y;
        for (y = 0; y < GL_HEIGHT/2; y++) {
            int x;
            for (x = 0; x < GL_WIDTH; x++)
                GL_FB[y * GL_WIDTH + x] = GL_RGB(30, 30, 80 + y/4);
        }
        /* Floor */
        for (y = GL_HEIGHT/2; y < GL_HEIGHT; y++) {
            int x;
            for (x = 0; x < GL_WIDTH; x++)
                GL_FB[y * GL_WIDTH + x] = GL_RGB(60, 40, 20);
        }

        /* Raycaster */
        int col;
        for (col = 0; col < GL_WIDTH; col++) {
            int ray_ang = angle + (col - GL_WIDTH/2) * 60 / GL_WIDTH;
            fixed_t ray_dx = fx_cos(ray_ang);
            fixed_t ray_dy = fx_sin(ray_ang);

            fixed_t rx = px, ry = py;
            int hit = 0;
            int step;
            for (step = 0; step < 200 && !hit; step++) {
                rx += ray_dx / 32;
                ry += ray_dy / 32;
                int mx = rx >> 16;
                int my = ry >> 16;
                if (mx < 0 || mx >= MAP_W || my < 0 || my >= MAP_H) { hit = 1; break; }
                if (dmap[my][mx]) hit = 1;
            }

            /* Distance = step / 200.0 */
            int dist = step;
            if (dist < 1) dist = 1;
            int wall_h = GL_HEIGHT * 5 / dist;
            if (wall_h > GL_HEIGHT) wall_h = GL_HEIGHT;
            int wall_top    = (GL_HEIGHT - wall_h) / 2;
            int wall_bottom = wall_top + wall_h;

            unsigned int shade = (unsigned int)(255 - dist * 8);
            if (shade > 255) shade = 20;
            unsigned int wall_col = GL_RGB(shade/2, shade/3, shade/4);
            if ((ray_ang / 5) & 1) wall_col = GL_RGB(shade/3, shade/4, shade/2);

            for (y = wall_top; y < wall_bottom; y++)
                if (y >= 0 && y < GL_HEIGHT)
                    GL_FB[y * GL_WIDTH + col] = wall_col;
        }

        gl_text(180, 10, "KSDOS DOOM Engine - gold4 SDK", GL_YELLOW, 0);
        gl_text(205, 22, "Raycaster  -  Press key to exit", GL_WHITE, 0);

        /* Autorotate player slightly */
        (void)px; (void)py;

        delay_gl(800000);
        if (inb(0x64) & 1) break;
    }
    gl_shutdown();
}
