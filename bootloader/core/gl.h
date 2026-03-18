/* KSDOS - Software OpenGL (Bochs VBE / fixed-point 3D) */
#ifndef GL_H
#define GL_H

/* ------------------------------------------------------------------ */
/*  Bochs VBE I/O (works in 32-bit protected mode inside QEMU)        */
/* ------------------------------------------------------------------ */
#define VBE_DISPI_IOPORT_INDEX   0x01CE
#define VBE_DISPI_IOPORT_DATA    0x01CF
#define VBE_DISPI_INDEX_ID       0
#define VBE_DISPI_INDEX_XRES     1
#define VBE_DISPI_INDEX_YRES     2
#define VBE_DISPI_INDEX_BPP      3
#define VBE_DISPI_INDEX_ENABLE   4
#define VBE_DISPI_DISABLED       0x00
#define VBE_DISPI_ENABLED        0x01
#define VBE_DISPI_LFB_ENABLED    0x40

#define GL_WIDTH   640
#define GL_HEIGHT  480
#define GL_BPP     32

/* Linear framebuffer at QEMU/Bochs default LFB address */
#define GL_FB  ((volatile unsigned int *)0xE0000000)

/* ------------------------------------------------------------------ */
/*  Colour helpers                                                     */
/* ------------------------------------------------------------------ */
#define GL_RGB(r,g,b) (((unsigned int)(r)<<16)|((unsigned int)(g)<<8)|(unsigned int)(b))
#define GL_BLACK   GL_RGB(0,0,0)
#define GL_WHITE   GL_RGB(255,255,255)
#define GL_RED     GL_RGB(220,50,50)
#define GL_GREEN   GL_RGB(50,220,50)
#define GL_BLUE    GL_RGB(50,100,220)
#define GL_YELLOW  GL_RGB(220,220,50)
#define GL_CYAN    GL_RGB(50,220,220)
#define GL_MAGENTA GL_RGB(220,50,220)
#define GL_ORANGE  GL_RGB(220,140,50)

/* ------------------------------------------------------------------ */
/*  API                                                                */
/* ------------------------------------------------------------------ */
void gl_init(void);
void gl_shutdown(void);
void gl_clear(unsigned int color);
void gl_put_pixel(int x, int y, unsigned int color);
void gl_line(int x0, int y0, int x1, int y1, unsigned int color);
void gl_fill_triangle(int x0,int y0,int x1,int y1,int x2,int y2, unsigned int color);
void gl_text(int x, int y, const char *s, unsigned int fg, unsigned int bg);

/* High-level demos */
void gl_demo_psx(void);
void gl_demo_doom(void);
void gl_demo_cube(void);

#endif /* GL_H */
