/* KSDOS - MS-DOS style kernel with game dev commands
   VGA text mode 80x25  +  Bochs VBE OpenGL (640x480x32)
   PSYq (PS1) and GOLD4 (DOOM) engine launchers              */

#include "ksdos-sdk.h"

/* ================================================================== */
/* VGA / Bochs VBE defines                                           */
/* ================================================================== */
#define VGA_MEM   ((volatile unsigned short *)0xB8000)
#define VGA_COLS  80
#define VGA_ROWS  25

#define ATTR_NORMAL   0x07
#define ATTR_BRIGHT   0x0F
#define ATTR_YELLOW   0x0E
#define ATTR_GREEN    0x0A
#define ATTR_CYAN     0x0B
#define ATTR_RED      0x04
#define ATTR_BWHITE   0x70
#define ATTR_MAGENTA  0x05
#define ATTR_LBLUE    0x09

/* Bochs VBE ports (work in 32-bit PM, inside QEMU) */
#define VBE_INDEX  0x01CE
#define VBE_DATA   0x01CF
#define VBE_W      640
#define VBE_H      480
#define VBE_FB     ((volatile unsigned int *)0xE0000000)
#define RGB(r,g,b) (((unsigned int)(r)<<16)|((unsigned int)(g)<<8)|(unsigned int)(b))

/* ================================================================== */
/* Keyboard defines                                                   */
/* ================================================================== */
#define KEYBOARD_DATA    0x60
#define KEYBOARD_STATUS  0x64
#define KEYBOARD_CMD     0x64
#define KEY_ESC        0x01
#define KEY_BACKSPACE  0x0E
#define KEY_TAB        0x0F
#define KEY_ENTER      0x1C
#define KEY_LCTRL      0x1D
#define KEY_LSHIFT     0x2A
#define KEY_RSHIFT     0x36
#define KEY_LALT       0x38
#define KEY_CAPSLOCK   0x3A
#define KEY_F1  0x3B
#define KEY_F2  0x3C
#define KEY_F3  0x3D
#define KEY_F4  0x3E
#define KEY_F5  0x3F
#define KEY_UP   0x48
#define KEY_DOWN 0x50
#define KEY_LEFT 0x4B
#define KEY_RIGHT 0x4D
#define KEY_F11 0x57
#define KEY_F12 0x58
#define KEY_NUMLOCK    0x45
#define KEY_SCROLLLOCK 0x46
#define KEY_HOME 0x47
#define KEY_PGUP 0x49
#define KEY_KP_MINUS 0x4A
#define KEY_CENTER 0x4C
#define KEY_KP_PLUS 0x4E
#define KEY_END  0x4F
#define KEY_PGDN 0x51
#define KEY_INS  0x52
#define KEY_DEL  0x53
#define KEY_F6 0x40
#define KEY_F7 0x41
#define KEY_F8 0x42
#define KEY_F9 0x43
#define KEY_F10 0x44

/* ================================================================== */
/* Function prototypes                                               */
/* ================================================================== */
static void outb(unsigned short port, unsigned char val);
static void outw(unsigned short port, unsigned short val);
static unsigned char inb(unsigned short port);
static void delay(unsigned int count);
static void kbd_wait_write(void);
static void kbd_wait_read(void);
static void kbd_send_cmd(unsigned char cmd);
static void kbd_send_data(unsigned char data);
static unsigned char kbd_read_data(void);
static void kbd_set_leds(void);
static void kbd_init(void);
static int kbd_process_scancode(unsigned char scancode, unsigned char *ch);
static unsigned char kbd_getchar(void);
static int kbd_key_available(void);
static void tty_clear(void);
static void tty_put(int col, int row, char c, unsigned char attr);
static void tty_puts(int col, int row, const char *s, unsigned char attr);
static void tty_fill(int col, int row, int len, char c, unsigned char attr);
static void tty_set_cursor(int col, int row);
static void tty_cursor_enable(void);
static int slen(const char *s);
static int kstrcmp(const char *s1, const char *s2);
static void tty_puts_center(int row, const char *s, unsigned char attr);
static void tty_hline(int row, unsigned char attr);
static void read_line(int row, int col, char *buffer, int maxlen, int mask);
static void do_login(void);
static void boot_sequence(void);
static void draw_shell(void);
static void vbe_init(void);
static void vbe_shutdown(void);
static void gl_clear(unsigned int color);
static void gl_pixel(int x, int y, unsigned int c);
static void gl_line(int x0,int y0,int x1,int y1,unsigned int c);
static void gl_fill_tri(int x0,int y0,int x1,int y1,int x2,int y2,unsigned int c);
static void gl_text(int x,int y,const char *s,unsigned int fg,unsigned int bg);
static void gl_demo_cube(void);
static void gl_demo_psx(void);
static void gl_demo_doom(void);
static void sdk_init_system(void);
static void sdk_show_projects(void);
static void sdk_build_project_real(const char *project);
static void sdk_run_project_real(const char *project);
static void sdk_status_real(void);
void ksdos_boot_menu(void);
void ksdos_auto_run_game(const char *game_type);
void gl_real_demo_cube(void);
void gl_real_demo_psx(void);
void gl_real_demo_doom(void);
void gl_performance_benchmark(void);
void gl_multi_context_demo(void);

/* ================================================================== */
/* Keyboard state                                                     */
/* ================================================================== */
static struct {
    unsigned int shift_pressed : 1;
    unsigned int ctrl_pressed  : 1;
    unsigned int alt_pressed   : 1;
    unsigned int caps_lock     : 1;
    unsigned int num_lock      : 1;
    unsigned int scroll_lock   : 1;
    unsigned int extended      : 1;
} kbd_state = {0};

static const unsigned char kbd_us[128] = {
    0, KEY_ESC,'1','2','3','4','5','6','7','8','9','0','-','=','\b',
    '\t','q','w','e','r','t','y','u','i','o','p','[',']','\n',
    KEY_LCTRL,'a','s','d','f','g','h','j','k','l',';','\'','`',
    KEY_LSHIFT,'\\','z','x','c','v','b','n','m',',','.','/',KEY_RSHIFT,
    '*',KEY_LALT,' ',KEY_CAPSLOCK,KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5,
    KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_NUMLOCK,KEY_SCROLLLOCK,
    KEY_HOME,KEY_UP,KEY_PGUP,KEY_KP_MINUS,KEY_LEFT,KEY_CENTER,KEY_RIGHT,
    KEY_KP_PLUS,KEY_END,KEY_DOWN,KEY_PGDN,KEY_INS,KEY_DEL,0,0,0,
    KEY_F11,KEY_F12
};
static const unsigned char kbd_us_shift[128] = {
    0,KEY_ESC,'!','@','#','$','%','^','&','*','(',')','_','+','\b',
    '\t','Q','W','E','R','T','Y','U','I','O','P','{','}','\n',
    KEY_LCTRL,'A','S','D','F','G','H','J','K','L',':','"','~',
    KEY_LSHIFT,'|','Z','X','C','V','B','N','M','<','>','?',KEY_RSHIFT,
    '*',KEY_LALT,' ',KEY_CAPSLOCK,KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5,
    KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_NUMLOCK,KEY_SCROLLLOCK,
    KEY_HOME,KEY_UP,KEY_PGUP,KEY_KP_MINUS,KEY_LEFT,KEY_CENTER,KEY_RIGHT,
    KEY_KP_PLUS,KEY_END,KEY_DOWN,KEY_PGDN,KEY_INS,KEY_DEL,0,0,0,
    KEY_F11,KEY_F12
};

/* ================================================================== */
/* Low-level I/O                                                     */
/* ================================================================== */
static void outb(unsigned short port, unsigned char val) {
    __asm__ volatile ("outb %0,%1"::"a"(val),"Nd"(port));
}
static void outw(unsigned short port, unsigned short val) {
    __asm__ volatile ("outw %0,%1"::"a"(val),"Nd"(port));
}
static unsigned char inb(unsigned short port) {
    unsigned char val;
    __asm__ volatile ("inb %1,%0":"=a"(val):"Nd"(port));
    return val;
}
static void delay(unsigned int count) {
    volatile unsigned int i;
    for (i = 0; i < count; i++) __asm__ volatile ("nop");
}

/* ================================================================== */
/* Keyboard driver                                                   */
/* ================================================================== */
static void kbd_wait_write(void) { while (inb(KEYBOARD_STATUS) & 2); }
static void kbd_wait_read(void)  { while (!(inb(KEYBOARD_STATUS) & 1)); }
static void kbd_send_cmd(unsigned char c)  { kbd_wait_write(); outb(KEYBOARD_CMD, c); }
static void kbd_send_data(unsigned char d) { kbd_wait_write(); outb(KEYBOARD_DATA, d); }
static unsigned char kbd_read_data(void)   { kbd_wait_read(); return inb(KEYBOARD_DATA); }

static void kbd_set_leds(void) {
    unsigned char s = 0;
    if (kbd_state.scroll_lock) s |= 1;
    if (kbd_state.num_lock)    s |= 2;
    if (kbd_state.caps_lock)   s |= 4;
    kbd_send_data(0xED); kbd_read_data();
    kbd_send_data(s);    kbd_read_data();
}

static void kbd_init(void) {
    unsigned char ack;
    kbd_send_cmd(0xAD); delay(1000);
    while (inb(KEYBOARD_STATUS) & 1) inb(KEYBOARD_DATA);
    kbd_send_cmd(0xFF);
    ack = kbd_read_data(); (void)ack;
    ack = kbd_read_data(); (void)ack;
    kbd_send_cmd(0xAE); delay(1000);
    kbd_send_data(0xF3); kbd_read_data();
    kbd_send_data(0x00); kbd_read_data();
    kbd_send_data(0xF4); kbd_read_data();
    kbd_set_leds();
}

static int kbd_process_scancode(unsigned char scancode, unsigned char *ch) {
    int is_break = (scancode & 0x80) ? 1 : 0;
    unsigned char key = scancode & 0x7F;
    unsigned char result = 0;
    if (scancode == 0xE0) { kbd_state.extended = 1; return 0; }
    if (!is_break) {
        switch (key) {
            case KEY_LSHIFT: case KEY_RSHIFT: kbd_state.shift_pressed = 1; return 0;
            case KEY_LCTRL:  kbd_state.ctrl_pressed = 1; return 0;
            case KEY_LALT:   kbd_state.alt_pressed  = 1; return 0;
            case KEY_CAPSLOCK:   kbd_state.caps_lock   = !kbd_state.caps_lock;   kbd_set_leds(); return 0;
            case KEY_NUMLOCK:    kbd_state.num_lock    = !kbd_state.num_lock;     kbd_set_leds(); return 0;
            case KEY_SCROLLLOCK: kbd_state.scroll_lock = !kbd_state.scroll_lock; kbd_set_leds(); return 0;
            default: break;
        }
        result = kbd_state.shift_pressed ? kbd_us_shift[key] : kbd_us[key];
        if (kbd_state.caps_lock && result >= 'a' && result <= 'z') result -= 32;
        else if (kbd_state.caps_lock && result >= 'A' && result <= 'Z') result += 32;
        if (kbd_state.extended) {
            switch (key) {
                case KEY_UP:    result = 0xE0; break;
                case KEY_DOWN:  result = 0xE1; break;
                case KEY_LEFT:  result = 0xE2; break;
                case KEY_RIGHT: result = 0xE3; break;
                default: break;
            }
        }
        *ch = result; kbd_state.extended = 0; return 1;
    } else {
        switch (key) {
            case KEY_LSHIFT: case KEY_RSHIFT: kbd_state.shift_pressed = 0; break;
            case KEY_LCTRL:  kbd_state.ctrl_pressed  = 0; break;
            case KEY_LALT:   kbd_state.alt_pressed   = 0; break;
            default: break;
        }
        kbd_state.extended = 0; return 0;
    }
}

static unsigned char kbd_getchar(void) {
    unsigned char scancode, ch;
    while (1) {
        scancode = kbd_read_data();
        if (kbd_process_scancode(scancode, &ch)) return ch;
    }
}
static int kbd_key_available(void) { return (inb(KEYBOARD_STATUS) & 1) ? 1 : 0; }

/* ================================================================== */
/* VGA text-mode driver                                              */
/* ================================================================== */
static void tty_clear(void) {
    unsigned int i;
    for (i = 0; i < VGA_COLS * VGA_ROWS; i++)
        VGA_MEM[i] = (unsigned short)(ATTR_NORMAL << 8) | ' ';
}
static void tty_put(int col, int row, char c, unsigned char attr) {
    if (col<0||col>=VGA_COLS||row<0||row>=VGA_ROWS) return;
    VGA_MEM[row*VGA_COLS+col] = (unsigned short)(attr<<8)|(unsigned char)c;
}
static void tty_puts(int col, int row, const char *s, unsigned char attr) {
    while (*s) tty_put(col++, row, *s++, attr);
}
static void tty_fill(int col, int row, int len, char c, unsigned char attr) {
    int i; for (i=0;i<len;i++) tty_put(col+i, row, c, attr);
}
static void tty_set_cursor(int col, int row) {
    unsigned short pos=(unsigned short)(row*VGA_COLS+col);
    outb(0x3D4,0x0F); outb(0x3D5,(unsigned char)(pos&0xFF));
    outb(0x3D4,0x0E); outb(0x3D5,(unsigned char)((pos>>8)&0xFF));
}
static void tty_cursor_enable(void) {
    outb(0x3D4,0x0A); outb(0x3D5,13);
    outb(0x3D4,0x0B); outb(0x3D5,15);
}

/* ================================================================== */
/* String helpers                                                    */
/* ================================================================== */
static int slen(const char *s) { int n=0; while(s[n]) n++; return n; }
static int kstrcmp(const char *a, const char *b) {
    while (*a && *a==*b){ a++; b++; } return *a-*b;
}
static void kcopy(char *dst, const char *src, int n) {
    int i=0; while(i<n-1&&src[i]){ dst[i]=src[i]; i++; } dst[i]='\0';
}
static int kparse(const char *buf, char *a0, char *a1) {
    int i=0,j=0; a0[0]=a1[0]='\0';
    while(buf[i]==' ') i++;
    while(buf[i]&&buf[i]!=' ') {
        a0[j++]=buf[i++];
    }
    a0[j]='\0';
    while(buf[i]==' ') i++;
    j=0;
    while(buf[i]) {
        a1[j++]=buf[i++];
    }
    a1[j]='\0';
    return (a0[0]!='\0')+(a1[0]!='\0');
}
static void tty_puts_center(int row, const char *s, unsigned char attr) {
    int col=(VGA_COLS-slen(s))/2; if(col<0)col=0; tty_puts(col,row,s,attr);
}
static void tty_hline(int row, unsigned char attr) {
    tty_fill(0,row,VGA_COLS,(char)0xCD,attr);
}

/* ================================================================== */
/* Command history + read_line                                       */
/* ================================================================== */
#define HIST_MAX 8
#define CMD_MAX  80
static char history[HIST_MAX][CMD_MAX];
static int  hist_n = 0;

static void hist_push(const char *cmd) {
    if (!cmd[0]) return;
    int i; for(i=HIST_MAX-1;i>0;i--) kcopy(history[i],history[i-1],CMD_MAX);
    kcopy(history[0],cmd,CMD_MAX);
    if(hist_n<HIST_MAX) hist_n++;
}

static void read_line(int row, int col, char *buf, int maxlen, int mask) {
    int pos=0, hidx=-1;
    unsigned char c;
    buf[0]='\0'; tty_set_cursor(col,row);
    while(1){
        c=kbd_getchar();
        if(c=='\n'||(unsigned char)c==(unsigned char)KEY_ENTER){ buf[pos]='\0'; break; }
        else if(c=='\b'||(unsigned char)c==(unsigned char)KEY_BACKSPACE){
            if(pos>0){ pos--; tty_put(col+pos,row,' ',ATTR_NORMAL); tty_set_cursor(col+pos,row); }
        }
        else if(c==0xE0){ /* UP - older history */
            int ni=hidx+1; if(ni<hist_n){ hidx=ni; kcopy(buf,history[hidx],maxlen); pos=slen(buf);
                tty_fill(col,row,maxlen-1,' ',ATTR_NORMAL); tty_puts(col,row,buf,ATTR_NORMAL);
                tty_set_cursor(col+pos,row); }
        }
        else if(c==0xE1){ /* DOWN - newer history */
            if(hidx>0){ hidx--; kcopy(buf,history[hidx],maxlen); }
            else{ hidx=-1; buf[0]='\0'; }
            pos=slen(buf);
            tty_fill(col,row,maxlen-1,' ',ATTR_NORMAL); tty_puts(col,row,buf,ATTR_NORMAL);
            tty_set_cursor(col+pos,row);
        }
        else if(c>=0x20&&c<=0x7E){
            if(pos<maxlen-1){ buf[pos]=c; tty_put(col+pos,row,mask?'*':c,ATTR_NORMAL);
                pos++; tty_set_cursor(col+pos,row); }
        }
    }
    buf[pos]='\0';
}

/* ================================================================== */
/* Bochs VBE + Software OpenGL (640x480x32bpp)                      */
/* ================================================================== */
static void vbe_write(unsigned short idx, unsigned short val) {
    outw(VBE_INDEX,idx); outw(VBE_DATA,val);
}
static void vbe_init(void) {
    vbe_write(4,0x00); vbe_write(1,VBE_W); vbe_write(2,VBE_H);
    vbe_write(3,32);   vbe_write(4,0x01|0x40); /* ENABLE|LFB */
}
static void vbe_shutdown(void) {
    vbe_write(4,0x00);
    outb(0x3C2,0x67);
    outb(0x3D4,0x00); outb(0x3D5,0x5F);
    outb(0x3D4,0x01); outb(0x3D5,0x4F);
    outb(0x3D4,0x06); outb(0x3D5,0xBF);
}

static void gl_clear(unsigned int color) {
    unsigned int i; for(i=0;i<(unsigned int)(VBE_W*VBE_H);i++) VBE_FB[i]=color;
}
static void gl_pixel(int x, int y, unsigned int c) {
    if((unsigned int)x<(unsigned int)VBE_W&&(unsigned int)y<(unsigned int)VBE_H)
        VBE_FB[y*VBE_W+x]=c;
}
static void gl_line(int x0,int y0,int x1,int y1,unsigned int c){
    int dx=x1-x0; if(dx<0)dx=-dx;
    int dy=y1-y0; if(dy<0)dy=-dy;
    int sx=(x0<x1)?1:-1, sy=(y0<y1)?1:-1, e=dx-dy;
    for(;;){ gl_pixel(x0,y0,c); if(x0==x1&&y0==y1)break;
        int e2=2*e; if(e2>-dy){e-=dy;x0+=sx;} if(e2<dx){e+=dx;y0+=sy;} }
}
static void gl_fb(int x0,int y0,int x1,int y1,int x2,int y2,unsigned int c,int bottom){
    (void)y1;
    int dy=bottom?(y2-y0):(y2-y0); if(!dy)return; int i,xi;
    for(i=0;i<=(y2-y0);i++){
        int xa,xb,y=y0+i;
        if(bottom){ xa=x0+(x1-x0)*i/dy; xb=x0+(x2-x0)*i/dy; }
        else       { xa=x0+(x2-x0)*i/dy; xb=x1+(x2-x1)*i/dy; }
        if(xa>xb){int t=xa;xa=xb;xb=t;}
        for(xi=xa;xi<=xb;xi++) gl_pixel(xi,y,c);
    }
}
static void gl_fill_tri(int x0,int y0,int x1,int y1,int x2,int y2,unsigned int c){
    int tx,ty;
#define SW(ax,ay,bx,by) tx=ax;ty=ay;ax=bx;ay=by;bx=tx;by=ty
    if(y0>y1){SW(x0,y0,x1,y1);}if(y0>y2){SW(x0,y0,x2,y2);}if(y1>y2){SW(x1,y1,x2,y2);}
#undef SW
    if(y1==y2)      gl_fb(x0,y0,x1,y1,x2,y2,c,1);
    else if(y0==y1) gl_fb(x0,y0,x1,y1,x2,y2,c,0);
    else{ int dy=y2-y0; if(!dy)return; int mx=x0+(x2-x0)*(y1-y0)/dy;
        gl_fb(x0,y0,x1,y1,mx,y1,c,1); gl_fb(x1,y1,mx,y1,x2,y2,c,0); }
}

/* 5x7 bitmap font */
static const unsigned char F5[96][5]={
{0x00,0x00,0x00,0x00,0x00},{0x00,0x00,0x5F,0x00,0x00},{0x00,0x07,0x00,0x07,0x00},
{0x14,0x7F,0x14,0x7F,0x14},{0x24,0x2A,0x7F,0x2A,0x12},{0x23,0x13,0x08,0x64,0x62},
{0x36,0x49,0x55,0x22,0x50},{0x00,0x05,0x03,0x00,0x00},{0x00,0x1C,0x22,0x41,0x00},
{0x00,0x41,0x22,0x1C,0x00},{0x14,0x08,0x3E,0x08,0x14},{0x08,0x08,0x3E,0x08,0x08},
{0x00,0x50,0x30,0x00,0x00},{0x08,0x08,0x08,0x08,0x08},{0x00,0x60,0x60,0x00,0x00},
{0x20,0x10,0x08,0x04,0x02},{0x3E,0x51,0x49,0x45,0x3E},{0x00,0x42,0x7F,0x40,0x00},
{0x42,0x61,0x51,0x49,0x46},{0x21,0x41,0x45,0x4B,0x31},{0x18,0x14,0x12,0x7F,0x10},
{0x27,0x45,0x45,0x45,0x39},{0x3C,0x4A,0x49,0x49,0x30},{0x01,0x71,0x09,0x05,0x03},
{0x36,0x49,0x49,0x49,0x36},{0x06,0x49,0x49,0x29,0x1E},{0x00,0x36,0x36,0x00,0x00},
{0x00,0x56,0x36,0x00,0x00},{0x08,0x14,0x22,0x41,0x00},{0x14,0x14,0x14,0x14,0x14},
{0x00,0x41,0x22,0x14,0x08},{0x02,0x01,0x51,0x09,0x06},{0x32,0x49,0x79,0x41,0x3E},
{0x7E,0x11,0x11,0x11,0x7E},{0x7F,0x49,0x49,0x49,0x36},{0x3E,0x41,0x41,0x41,0x22},
{0x7F,0x41,0x41,0x22,0x1C},{0x7F,0x49,0x49,0x49,0x41},{0x7F,0x09,0x09,0x09,0x01},
{0x3E,0x41,0x49,0x49,0x7A},{0x7F,0x08,0x08,0x08,0x7F},{0x00,0x41,0x7F,0x41,0x00},
{0x20,0x40,0x41,0x3F,0x01},{0x7F,0x08,0x14,0x22,0x41},{0x7F,0x40,0x40,0x40,0x40},
{0x7F,0x02,0x0C,0x02,0x7F},{0x7F,0x04,0x08,0x10,0x7F},{0x3E,0x41,0x41,0x41,0x3E},
{0x7F,0x09,0x09,0x09,0x06},{0x3E,0x41,0x51,0x21,0x5E},{0x7F,0x09,0x19,0x29,0x46},
{0x46,0x49,0x49,0x49,0x31},{0x01,0x01,0x7F,0x01,0x01},{0x3F,0x40,0x40,0x40,0x3F},
{0x1F,0x20,0x40,0x20,0x1F},{0x3F,0x40,0x38,0x40,0x3F},{0x63,0x14,0x08,0x14,0x63},
{0x07,0x08,0x70,0x08,0x07},{0x61,0x51,0x49,0x45,0x43},{0x00,0x7F,0x41,0x41,0x00},
{0x02,0x04,0x08,0x10,0x20},{0x00,0x41,0x41,0x7F,0x00},{0x04,0x02,0x01,0x02,0x04},
{0x40,0x40,0x40,0x40,0x40},{0x00,0x01,0x02,0x04,0x00},{0x20,0x54,0x54,0x54,0x78},
{0x7F,0x48,0x44,0x44,0x38},{0x38,0x44,0x44,0x44,0x20},{0x38,0x44,0x44,0x48,0x7F},
{0x38,0x54,0x54,0x54,0x18},{0x08,0x7E,0x09,0x01,0x02},{0x0C,0x52,0x52,0x52,0x3E},
{0x7F,0x08,0x04,0x04,0x78},{0x00,0x44,0x7D,0x40,0x00},{0x20,0x40,0x44,0x3D,0x00},
{0x7F,0x10,0x28,0x44,0x00},{0x00,0x41,0x7F,0x40,0x00},{0x7C,0x04,0x18,0x04,0x78},
{0x7C,0x08,0x04,0x04,0x78},{0x38,0x44,0x44,0x44,0x38},{0x7C,0x14,0x14,0x14,0x08},
{0x08,0x14,0x14,0x18,0x7C},{0x7C,0x08,0x04,0x04,0x08},{0x48,0x54,0x54,0x54,0x20},
{0x04,0x3F,0x44,0x40,0x20},{0x3C,0x40,0x40,0x20,0x7C},{0x1C,0x20,0x40,0x20,0x1C},
{0x3C,0x40,0x30,0x40,0x3C},{0x44,0x28,0x10,0x28,0x44},{0x0C,0x50,0x50,0x50,0x3C},
{0x44,0x64,0x54,0x4C,0x44},{0x00,0x08,0x36,0x41,0x00},{0x00,0x00,0x7F,0x00,0x00},
{0x00,0x41,0x36,0x08,0x00},{0x10,0x08,0x08,0x10,0x08},{0x7E,0x5D,0x5D,0x7E,0x00}
};

static void gl_text(int x, int y, const char *s, unsigned int fg, unsigned int bg) {
    while(*s){ unsigned char ch=(unsigned char)*s;
        if(ch>=32&&ch<=127){ int cx,cy;
            for(cx=0;cx<5;cx++) for(cy=0;cy<7;cy++)
                gl_pixel(x+cx,y+cy,(F5[ch-32][cx]&(1<<cy))?fg:bg); }
        x+=6; s++; }
}

/* ---- fixed-point 3D ---- */
typedef int fx_t;
#define FX(v)    ((fx_t)((v)*65536))
#define FMUL(a,b) ((fx_t)(((long long)(a)*(b))>>16))

static const fx_t SIN90[91]={
    0,1144,2287,3430,4572,5712,6850,7986,9120,10251,11380,12505,13626,14742,15854,
    16962,18064,19161,20252,21336,22415,23486,24551,25607,26656,27697,28729,29752,
    30767,31772,32768,33754,34730,35696,36650,37594,38526,39448,40358,41256,42142,
    43016,43878,44727,45563,46386,47195,47991,48773,49541,50296,51036,51762,52473,
    53170,53852,54520,55173,55811,56434,57042,57635,58213,58775,59322,59854,60370,
    60871,61356,61826,62279,62717,63139,63545,63935,64310,64668,65010,65326,65526,
    65536,65526,65510,65478,65430,65366,65287,65193,65083,64958,64818
};
static fx_t fsin(int d){
    d=((d%360)+360)%360;
    if(d<=90) return SIN90[d];
    if(d<=180) return SIN90[180-d];
    if(d<=270) return -SIN90[d-180];
    return -SIN90[360-d];
}
static fx_t fcos(int d){ return fsin(d+90); }

static void rot_proj(const fx_t v[3],int rx,int ry,int rz,int *px,int *py){
    fx_t x=v[0],y=v[1],z=v[2],t;
    t=FMUL(fcos(rx),y)-FMUL(fsin(rx),z); z=FMUL(fsin(rx),y)+FMUL(fcos(rx),z); y=t;
    t=FMUL(fcos(ry),x)+FMUL(fsin(ry),z); z=-FMUL(fsin(ry),x)+FMUL(fcos(ry),z); x=t;
    t=FMUL(fcos(rz),x)-FMUL(fsin(rz),y); y=FMUL(fsin(rz),x)+FMUL(fcos(rz),y); x=t;
    fx_t fz=z+FX(300); if(fz<FX(1))fz=FX(1);
    *px=VBE_W/2+(int)(FMUL(x,FX(256))/(fz>>16));
    *py=VBE_H/2+(int)(FMUL(y,FX(256))/(fz>>16));
}

/* ---- 3D Cube ---- */
static const fx_t CV[8][3]={
    {FX(-64),FX(-64),FX(-64)},{FX(64),FX(-64),FX(-64)},
    {FX(64), FX(64), FX(-64)},{FX(-64),FX(64), FX(-64)},
    {FX(-64),FX(-64),FX(64)}, {FX(64), FX(-64),FX(64)},
    {FX(64), FX(64), FX(64)}, {FX(-64),FX(64), FX(64)}
};
static const int CF[6][4]={{0,1,2,3},{4,5,6,7},{0,1,5,4},{2,3,7,6},{0,3,7,4},{1,2,6,5}};
static const unsigned int FC[6]={
    RGB(220,50,50),RGB(50,220,50),RGB(50,100,220),
    RGB(220,220,50),RGB(50,220,220),RGB(220,50,220)
};

static void gl_demo_cube(void) {
    vbe_init();
    int fr,i,f;
    for(fr=0;fr<300;fr++){
        gl_clear(RGB(10,10,30));
        gl_text(130,10,"KSDOS OpenGL 1.5 SW  - Rotating RGB Cube  [press key]",RGB(255,255,255),RGB(10,10,30));
        int px[8],py[8];
        for(i=0;i<8;i++) rot_proj(CV[i],fr*2,fr*3,fr,&px[i],&py[i]);
        for(f=0;f<6;f++){
            const int *fi=CF[f];
            unsigned int col=FC[f];
            unsigned int r=(col>>16)&0xFF,g=(col>>8)&0xFF,b=col&0xFF;
            unsigned int sh=(unsigned int)(160+f*12);
            r=r*sh/255; g=g*sh/255; b=b*sh/255; col=RGB(r,g,b);
            gl_fill_tri(px[fi[0]],py[fi[0]],px[fi[1]],py[fi[1]],px[fi[2]],py[fi[2]],col);
            gl_fill_tri(px[fi[0]],py[fi[0]],px[fi[2]],py[fi[2]],px[fi[3]],py[fi[3]],col);
            unsigned int ec=RGB(r+40>255?255:r+40,g+40>255?255:g+40,b+40>255?255:b+40);
            gl_line(px[fi[0]],py[fi[0]],px[fi[1]],py[fi[1]],ec);
            gl_line(px[fi[1]],py[fi[1]],px[fi[2]],py[fi[2]],ec);
            gl_line(px[fi[2]],py[fi[2]],px[fi[3]],py[fi[3]],ec);
            gl_line(px[fi[3]],py[fi[3]],px[fi[0]],py[fi[0]],ec);
        }
        delay(250000);
        if(kbd_key_available()){ inb(KEYBOARD_DATA); break; }
    }
    vbe_shutdown();
}

/* ---- PSYq PS1 demo ---- */
static void gl_demo_psx(void) {
    vbe_init();
    int fr;
    for(fr=0;fr<300;fr++){
        int y,x;
        for(y=0;y<VBE_H/2;y++){ unsigned int sky=RGB(20+y/4,10,80+y/3);
            for(x=0;x<VBE_W;x++) VBE_FB[y*VBE_W+x]=sky; }
        for(y=VBE_H/2;y<VBE_H;y++){ unsigned int g=(unsigned int)(30+(y-VBE_H/2)/6);
            for(x=0;x<VBE_W;x++) VBE_FB[y*VBE_W+x]=RGB(g,g+10,g/2); }
        int cx=VBE_W/2,cy=VBE_H/2;
        int r=80+(int)(FMUL(fsin(fr*3),FX(20))/65536);
        int a=fr*2;
        int x0=cx+r*(int)fcos(a)/65536,     y0=cy+r*(int)fsin(a)/65536;
        int x1=cx+r*(int)fcos(a+90)/65536,  y1=cy+r*(int)fsin(a+90)/65536;
        int x2=cx+r*(int)fcos(a+180)/65536, y2=cy+r*(int)fsin(a+180)/65536;
        int x3=cx+r*(int)fcos(a+270)/65536, y3=cy+r*(int)fsin(a+270)/65536;
        gl_fill_tri(x0,y0,x1,y1,x2,y2,RGB(180,20,20));
        gl_fill_tri(x0,y0,x2,y2,x3,y3,RGB(20,20,180));
        gl_line(x0,y0,x1,y1,RGB(255,255,255)); gl_line(x1,y1,x2,y2,RGB(255,255,255));
        gl_line(x2,y2,x3,y3,RGB(255,255,255)); gl_line(x3,y3,x0,y0,RGB(255,255,255));
        gl_text(165,16,"PSYq Engine  v4.7  -  PlayStation(R) 1 Dev Kit",RGB(255,220,0),0);
        gl_text(180,28,"PSn00bSDK / mipsel-none-elf-gcc 12.3.0",RGB(200,200,200),0);
        gl_text(215,40,"[press any key to exit]",RGB(180,180,180),0);
        delay(200000);
        if(kbd_key_available()){ inb(KEYBOARD_DATA); break; }
    }
    vbe_shutdown();
}

/* ---- GOLD4 DOOM raycaster ---- */
static const unsigned char DMAP[16][16]={
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,1,0,1,1,1,0,0,1,1,0,0,1,0,1},{1,0,1,0,0,0,1,0,0,1,0,0,0,1,0,1},
    {1,0,1,1,1,0,1,0,0,0,0,1,1,1,0,1},{1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,1,0,1,1,0,1,1,0,1,1,0,1,0,1},{1,0,0,0,1,0,0,0,0,0,0,1,0,0,0,1},
    {1,0,0,0,1,0,0,1,1,0,0,1,0,0,0,1},{1,0,1,0,0,0,0,0,0,0,0,0,0,1,0,1},
    {1,0,1,1,0,1,1,0,0,1,1,0,1,1,0,1},{1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1},
    {1,0,1,0,1,0,0,0,0,0,0,1,0,1,0,1},{1,0,1,1,1,1,1,0,0,1,1,1,1,1,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
};

static void gl_demo_doom(void) {
    vbe_init();
    int ang=0,fr,y,col;
    for(fr=0;fr<400;fr++){
        ang=(ang+1)%360;
        for(y=0;y<VBE_H/2;y++){ unsigned int sky=RGB(30,30,80+y/4);
            int x; for(x=0;x<VBE_W;x++) VBE_FB[y*VBE_W+x]=sky; }
        for(y=VBE_H/2;y<VBE_H;y++){
            int x; for(x=0;x<VBE_W;x++) VBE_FB[y*VBE_W+x]=RGB(60,40,20); }
        for(col=0;col<VBE_W;col++){
            int ray=ang+(col-VBE_W/2)*60/VBE_W;
            fx_t rdx=fcos(ray),rdy=fsin(ray),rx=FX(8),ry=FX(8);
            int step;
            for(step=0;step<200;step++){
                rx+=rdx/32; ry+=rdy/32;
                int mx=(int)(rx>>16),my=(int)(ry>>16);
                if(mx<0||mx>=16||my<0||my>=16||DMAP[my][mx]) break;
            }
            int dist=step; if(dist<1)dist=1;
            int wh=VBE_H*5/dist; if(wh>VBE_H)wh=VBE_H;
            int wt=(VBE_H-wh)/2;
            unsigned int sh=(unsigned int)(255-dist*7);
            if(sh>255)sh=20;
            unsigned int wc=((ray/5)&1)?RGB(sh/3,sh/4,sh/2):RGB(sh/2,sh/3,sh/4);
            for(y=wt;y<wt+wh;y++) if(y>=0&&y<VBE_H) VBE_FB[y*VBE_W+col]=wc;
        }
        gl_text(140,10,"GOLD4 Engine  v4.0  -  DOOM Raycaster  [GNU gold + djgpp gcc 12]",RGB(255,220,0),0);
        gl_text(215,22,"[press any key to exit]",RGB(200,200,200),0);
        delay(80000);
        if(kbd_key_available()){ inb(KEYBOARD_DATA); break; }
    }
    vbe_shutdown();
}

/* ================================================================== */
/* Login                                                             */
/* ================================================================== */
#define USERNAME "ksdos"
#define PASSWORD "ksdos"

static void do_login(void) {
    int attempts=0; char username[32],password[32]; kbd_init();
    while(attempts<3){
        tty_clear();
        tty_puts_center(10,"KSDOS Login",ATTR_BRIGHT);
        tty_puts(5,12,"Username: ",ATTR_NORMAL); read_line(12,15,username,32,0);
        tty_puts(5,13,"Password: ",ATTR_NORMAL); read_line(13,15,password,32,1);
        if(kstrcmp(username,USERNAME)==0&&kstrcmp(password,PASSWORD)==0) return;
        attempts++;
        tty_puts_center(15,"Invalid credentials. Press a key to retry.",ATTR_RED);
        kbd_getchar();
    }
    tty_clear(); tty_puts_center(12,"System locked.",ATTR_RED);
    for(;;) __asm__ volatile("cli;hlt");
}

/* ================================================================== */
/* Boot sequence with SDK initialization                             */
/* ================================================================== */
static void boot_sequence(void) {
    int r=0;
    tty_puts(0,r++,"Starting KSDOS Game Dev Edition...",      ATTR_NORMAL);  delay(12000000);
    tty_puts(0,r++,"HIMEM testing extended memory...",        ATTR_NORMAL);  delay(8000000);
    tty_puts(0,r++,"Loading KSDOS kernel drivers...",         ATTR_NORMAL);  delay(8000000);
    tty_puts(0,r++,"Initializing SDK system...",              ATTR_GREEN);   delay(8000000);
    tty_puts(0,r++,"  Detecting PSYq v4.7 SDK...",           ATTR_GREEN);   delay(6000000);
    tty_puts(0,r++,"  Detecting GOLD4 v4.0 SDK...",          ATTR_YELLOW);  delay(6000000);
    tty_puts(0,r++,"Initializing OpenGL SW 1.5 renderer...", ATTR_CYAN);    delay(8000000);
    tty_puts(0,r++,"  Bochs VBE 640x480x32bpp framebuffer",  ATTR_CYAN);    delay(6000000);
    tty_puts(0,r++,"Scanning game projects...",              ATTR_NORMAL);  delay(5000000);
    tty_puts(0,r++,"Reading CONFIG.SYS...",                  ATTR_NORMAL);  delay(5000000);
    tty_puts(0,r++,"Processing AUTOEXEC.BAT...",             ATTR_NORMAL);  delay(5000000);
    tty_puts(0,r++,"System ready.",                          ATTR_GREEN);   delay(4000000);
}

/* ================================================================== */
/* SDK System Implementation                                         */
/* ================================================================== */
static void sdk_init_system(void) {
    out_cls();
    out_print("Initializing KSDOS SDK System...", ATTR_CYAN);
    
    int result = ksdos_init_sdk_system();
    if (result == KSDOS_SDK_SUCCESS) {
        out_print("SDK system initialized successfully", ATTR_GREEN);
        ksdos_show_sdk_status();
    } else {
        out_print("Failed to initialize SDK system", ATTR_RED);
    }
    
    out_print("Available game projects:", ATTR_YELLOW);
    ksdos_show_projects();
}

static void sdk_show_projects(void) {
    ksdos_list_available_projects();
    
    /* Display projects from global buffer */
    extern char build_output[];
    extern int build_output_pos;
    
    char *line = build_output;
    int line_start = 0;
    
    for (int i = 0; i < build_output_pos; i++) {
        if (build_output[i] == '\r' && build_output[i + 1] == '\n') {
            build_output[i] = '\0';
            out_print(line, ATTR_NORMAL);
            line_start = i + 2;
            line = build_output + line_start;
            i++;
        }
    }
}

static void sdk_build_project_real(const char *project) {
    out_cls();
    char msg[256];
    int pos = 0;
    
    kcopy(msg, "Building project: ", sizeof(msg));
    pos += slen("Building project: ");
    kcopy(msg + pos, project, sizeof(msg) - pos);
    
    out_print(msg, ATTR_CYAN);
    
    int result = ksdos_build_game(project);
    if (result == KSDOS_SDK_SUCCESS) {
        out_print("Build completed successfully", ATTR_GREEN);
        
        /* Show build output */
        extern char build_output[];
        extern int build_output_pos;
        
        char *line = build_output;
        int line_start = 0;
        
        for (int i = 0; i < build_output_pos; i++) {
            if (build_output[i] == '\r' && build_output[i + 1] == '\n') {
                build_output[i] = '\0';
                out_print(line, ATTR_NORMAL);
                line_start = i + 2;
                line = build_output + line_start;
                i++;
            }
        }
    } else {
        out_print("Build failed", ATTR_RED);
    }
}

static void sdk_run_project_real(const char *project) {
    out_cls();
    char msg[256];
    int pos = 0;
    
    kcopy(msg, "Running project: ", sizeof(msg));
    pos += slen("Running project: ");
    kcopy(msg + pos, project, sizeof(msg) - pos);
    
    out_print(msg, ATTR_CYAN);
    out_print("Launching game...", ATTR_YELLOW);
    
    int result = ksdos_run_game(project);
    if (result == KSDOS_SDK_SUCCESS) {
        out_print("Game completed", ATTR_GREEN);
    } else {
        out_print("Failed to run game", ATTR_RED);
    }
}

static void sdk_status_real(void) {
    out_cls();
    out_print("KSDOS SDK Status:", ATTR_CYAN);
    ksdos_show_sdk_status();
    
    /* Show SDK status from global buffer */
    extern char build_output[];
    extern int build_output_pos;
    
    char *line = build_output;
    int line_start = 0;
    
    for (int i = 0; i < build_output_pos; i++) {
        if (build_output[i] == '\r' && build_output[i + 1] == '\n') {
            build_output[i] = '\0';
            out_print(line, ATTR_NORMAL);
            line_start = i + 2;
            line = build_output + line_start;
            i++;
        }
    }
}

/* ================================================================== */
/* Scrollable output area (rows 16-22)                              */
/* ================================================================== */
#define OUT_TOP  16
#define OUT_BOT  22
#define OUT_ROWS (OUT_BOT-OUT_TOP+1)
static char outbuf[OUT_ROWS][VGA_COLS+1];
static int  outn=0;

static void out_scroll(void){
    int i,j;
    for(i=0;i<OUT_ROWS-1;i++){
        for(j=0;j<VGA_COLS;j++){
            tty_put(j,OUT_TOP+i,outbuf[i+1][j],ATTR_NORMAL);
            outbuf[i][j]=outbuf[i+1][j];
        }
        outbuf[i][VGA_COLS]='\0';
    }
    tty_fill(0,OUT_BOT,VGA_COLS,' ',ATTR_NORMAL);
    outbuf[OUT_ROWS-1][0]='\0';
}
static void out_print(const char *s, unsigned char attr){
    if(outn>=OUT_ROWS) out_scroll(); else outn++;
    int row=OUT_TOP+outn-1, i;
    for(i=0;i<VGA_COLS&&s[i];i++){ tty_put(i,row,s[i],attr); outbuf[outn-1][i]=s[i]; }
    for(;i<VGA_COLS;i++) outbuf[outn-1][i]=' ';
    outbuf[outn-1][VGA_COLS]='\0';
}
static void out_cls(void){
    int i; for(i=OUT_TOP;i<=OUT_BOT;i++) tty_fill(0,i,VGA_COLS,' ',ATTR_NORMAL);
    outn=0;
}

/* ================================================================== */
/* PSYq engine IDE screen                                            */
/* ================================================================== */
static void engine_psx(void){
    tty_clear();
    tty_fill(0,0,VGA_COLS,' ',ATTR_BWHITE);
    tty_puts_center(0," PSYq Engine IDE  |  PlayStation(R) 1 Development ",ATTR_BWHITE);
    tty_hline(1,ATTR_NORMAL);
    tty_puts(0,2," SDK:  PSYq v4.7 (PSn00bSDK)  |  mipsel-none-elf-gcc 12.3.0",ATTR_CYAN);
    tty_puts(0,3," TOOL: elf2x (ELF->PS-EXE) | cdgen (ISO) | pcsx-redux (emu)",ATTR_CYAN);
    tty_hline(4,ATTR_NORMAL);
    tty_puts(0,5," [PROJECT STRUCTURE]  C:\\GAMES\\PSX\\MYGAME\\",ATTR_YELLOW);
    tty_puts(0,6,"   main.c   - Entry point, game loop, VSYNC",ATTR_NORMAL);
    tty_puts(0,7,"   gfx.c    - GPU primitives (GPU_Poly_F3, GPU_Rect, OT)",ATTR_NORMAL);
    tty_puts(0,8,"   pad.c    - Controller (PAD_CROSS PAD_CIRCLE PAD_TRIANGLE)",ATTR_NORMAL);
    tty_puts(0,9,"   spu.c    - SPU sound channels, VAG samples",ATTR_NORMAL);
    tty_puts(0,10,"   gte.c    - GTE geometry engine (RTPS MVMVA NCLIP)",ATTR_NORMAL);
    tty_puts(0,11,"   cd.c     - CD-ROM file streaming (CdReadFile)",ATTR_NORMAL);
    tty_hline(12,ATTR_NORMAL);
    tty_puts(0,13," [BUILD COMMAND]",ATTR_GREEN);
    tty_puts(0,14,"  mipsel-none-elf-gcc -msoft-float -nostdlib -Ttext 0x80010000 \\",ATTR_NORMAL);
    tty_puts(0,15,"    -I$(PSYQ)/include -L$(PSYQ)/lib -lps \\",ATTR_NORMAL);
    tty_puts(0,16,"    main.c gfx.c pad.c spu.c gte.c cd.c -o MYGAME.ELF",ATTR_NORMAL);
    tty_puts(0,17,"  elf2x -q MYGAME.ELF MYGAME.EXE    (-> PS1 executable)",ATTR_NORMAL);
    tty_hline(18,ATTR_NORMAL);
    tty_puts(0,19," [KSDOS COMMANDS]",ATTR_CYAN);
    tty_puts(0,20,"  makegame psx   - compile project    playgame psx - run demo",ATTR_NORMAL);
    tty_puts(0,21,"  gl psx         - PSYq OpenGL demo   engine psx   - this IDE",ATTR_NORMAL);
    tty_hline(22,ATTR_NORMAL);
    tty_puts(0,23,"  Press any key to return to shell...",ATTR_YELLOW);
    kbd_getchar();
}

/* ================================================================== */
/* GOLD4 engine IDE screen                                           */
/* ================================================================== */
static void engine_doom(void){
    tty_clear();
    tty_fill(0,0,VGA_COLS,' ',ATTR_BWHITE);
    tty_puts_center(0," GOLD4 Engine IDE  |  DOOM-era DOS Game Development ",ATTR_BWHITE);
    tty_hline(1,ATTR_NORMAL);
    tty_puts(0,2," SDK:  GOLD4 v4.0  |  GNU gold linker  |  djgpp gcc 12.3",ATTR_YELLOW);
    tty_puts(0,3," TOOL: deutex (WAD) | DeuSF | SLADE3 | DOSBox-X (emulator)",ATTR_YELLOW);
    tty_hline(4,ATTR_NORMAL);
    tty_puts(0,5," [PROJECT STRUCTURE]  C:\\GAMES\\DOOM\\MYWAD\\",ATTR_YELLOW);
    tty_puts(0,6,"   main.c    - Entry, game loop, Mode 13h (VGA 320x200x256)",ATTR_NORMAL);
    tty_puts(0,7,"   r_draw.c  - Raycaster, column renderer, perspective",ATTR_NORMAL);
    tty_puts(0,8,"   m_map.c   - BSP tree, WAD map loader, sectors/linedefs",ATTR_NORMAL);
    tty_puts(0,9,"   i_sound.c - OPL2/OPL3 music, PC speaker SFX",ATTR_NORMAL);
    tty_puts(0,10,"   g_game.c  - Player, things, actions, triggers",ATTR_NORMAL);
    tty_puts(0,11,"   MYWAD.WAD - Asset lump file (flats,patches,music,maps)",ATTR_NORMAL);
    tty_hline(12,ATTR_NORMAL);
    tty_puts(0,13," [BUILD COMMAND]",ATTR_GREEN);
    tty_puts(0,14,"  djgpp-gcc -O2 -std=gnu99 -DDOOM -march=i386 \\",ATTR_NORMAL);
    tty_puts(0,15,"    -I$(GOLD4)/include  main.c r_draw.c m_map.c \\",ATTR_NORMAL);
    tty_puts(0,16,"    i_sound.c g_game.c -o DOOM.EXE \\",ATTR_NORMAL);
    tty_puts(0,17,"    -Wl,-plugin-opt=O2 -fuse-ld=gold  (GNU gold linker)",ATTR_NORMAL);
    tty_puts(0,18,"  deutex -build MYWAD.wad   (builds WAD from source tree)",ATTR_NORMAL);
    tty_hline(19,ATTR_NORMAL);
    tty_puts(0,20," [KSDOS COMMANDS]",ATTR_CYAN);
    tty_puts(0,21,"  makegame doom  - compile project   playgame doom - run demo",ATTR_NORMAL);
    tty_puts(0,22,"  gl doom        - raycaster demo    engine doom   - this IDE",ATTR_NORMAL);
    tty_hline(23,ATTR_NORMAL);
    tty_puts_center(24,"  Press any key to return...",ATTR_YELLOW);
    kbd_getchar();
}

/* ================================================================== */
/* makegame – simulated build pipeline                              */
/* ================================================================== */
static void makegame_psx(void){
    out_cls();
    out_print(" PSYq Build System v4.7 - mipsel-none-elf-gcc",ATTR_CYAN);
    out_print(" [1/7] main.c   -> main.o    ...", ATTR_NORMAL); delay(12000000);
    out_print(" [2/7] gfx.c    -> gfx.o     ...", ATTR_NORMAL); delay(11000000);
    out_print(" [3/7] pad.c    -> pad.o     ...", ATTR_NORMAL); delay(10000000);
    out_print(" [4/7] spu.c    -> spu.o     ...", ATTR_NORMAL); delay(10000000);
    out_print(" [5/7] gte.c    -> gte.o     ...", ATTR_NORMAL); delay(10000000);
    out_print(" [6/7] Linking MYGAME.ELF (mipsel-none-elf-ld)...",ATTR_NORMAL); delay(14000000);
    out_print(" [7/7] elf2x -> MYGAME.EXE  (PS-EXE format)...",ATTR_NORMAL);    delay(10000000);
    out_print(" Build OK -> C:\\GAMES\\PSX\\MYGAME.EXE  (run: playgame psx)",ATTR_GREEN);
}

static void makegame_doom(void){
    out_cls();
    out_print(" GOLD4 Build System v4.0 - djgpp + GNU gold linker",ATTR_YELLOW);
    out_print(" [1/7] main.c    -> main.o   ...", ATTR_NORMAL); delay(10000000);
    out_print(" [2/7] r_draw.c  -> r_draw.o ...", ATTR_NORMAL); delay(10000000);
    out_print(" [3/7] m_map.c   -> m_map.o  ...", ATTR_NORMAL); delay(10000000);
    out_print(" [4/7] i_sound.c -> i_sound.o...", ATTR_NORMAL); delay(10000000);
    out_print(" [5/7] g_game.c  -> g_game.o ...", ATTR_NORMAL); delay(10000000);
    out_print(" [6/7] Linking DOOM.EXE  (ld.gold -O2 -plugin-opt=O2)...",ATTR_NORMAL); delay(14000000);
    out_print(" [7/7] deutex -build MYWAD.WAD ...",ATTR_NORMAL); delay(10000000);
    out_print(" Build OK -> DOOM.EXE + MYWAD.WAD  (run: playgame doom)",ATTR_GREEN);
}

/* ================================================================== */
/* Shell header                                                      */
/* ================================================================== */
static void draw_header(void){
    tty_fill(0,0,VGA_COLS,' ',ATTR_BWHITE);
    tty_puts_center(0,"KSDOS 1.0  |  PSYq v4.7  |  GOLD4 v4.0  |  OpenGL SW 1.5",ATTR_BWHITE);
    tty_puts(0,1,"(C)Copyright KSDOS Corp 1994-2026. All rights reserved.",ATTR_NORMAL);
    tty_hline(2,ATTR_NORMAL);
    tty_puts(0,3,"  MEM:640KB  PSYq:mipsel-none-elf-gcc 12.3  GOLD4:djgpp+gold  GL:Bochs VBE",ATTR_NORMAL);
    tty_hline(4,ATTR_NORMAL);
    tty_puts_center(6,"*** KSDOS GAME DEV EDITION  -  PS1 & DOOM DEVELOPMENT  ***",ATTR_BRIGHT);
    tty_hline(8,ATTR_NORMAL);
    tty_puts(0,12,"  help       - list all commands",         ATTR_CYAN);
    tty_puts(0,13,"  engine psx  - PSYq IDE      engine doom  - GOLD4 IDE",ATTR_CYAN);
    tty_puts(0,14,"  makegame psx/doom  - build  playgame psx/doom  - 3D demo",ATTR_CYAN);
    tty_puts(0,15,"  gl [psx|doom|cube]  - OpenGL demo    sdk init/build/run/status",ATTR_CYAN);
    tty_hline(13,ATTR_NORMAL);
    tty_hline(15,ATTR_NORMAL);
    out_cls();
    tty_hline(OUT_BOT+1,ATTR_NORMAL);
}

/* ================================================================== */
/* Main shell loop                                                   */
/* ================================================================== */
static void draw_shell(void){
    char line[CMD_MAX], arg0[CMD_MAX], arg1[CMD_MAX];
    int running=1;
    tty_clear(); draw_header();

    while(running){
        tty_fill(0,23,VGA_COLS,' ',ATTR_NORMAL);
        tty_puts(0,23,"C:\\>",ATTR_GREEN);
        read_line(23,4,line,sizeof(line),0);
        hist_push(line);
        kparse(line,arg0,arg1);

        if(kstrcmp(arg0,"help")==0){
            out_print("Commands: help cls ver sysinfo exit",ATTR_CYAN);
            out_print("  makegame [psx|doom]   playgame [psx|doom]",ATTR_CYAN);
            out_print("  engine   [psx|doom]   gl [psx|doom|cube|bench|multi]",ATTR_CYAN);
            out_print("  sdk init/build/run/status  - Real SDK commands",ATTR_CYAN);
        }
        else if(kstrcmp(arg0,"cls")==0){ tty_clear(); draw_header(); }
        else if(kstrcmp(arg0,"ver")==0){
            out_print("KSDOS 1.0 Game Dev Edition",ATTR_NORMAL);
            out_print("PSYq v4.7 | GOLD4 v4.0 | OpenGL SW 1.5 | gcc 14.2",ATTR_NORMAL);
        }
        else if(kstrcmp(arg0,"sysinfo")==0){
            out_print("CPU: i386 32-bit protected mode",ATTR_NORMAL);
            out_print("GPU: Bochs VBE 640x480x32  (OpenGL SW 1.5)",ATTR_NORMAL);
            out_print("SDK: PSYq 4.7 (mipsel-none-elf) | GOLD4 4.0 (gold+djgpp)",ATTR_NORMAL);
            out_print("MEM: 640KB conv + 16MB extended via VBE LFB",ATTR_NORMAL);
        }
        else if(kstrcmp(arg0,"gl")==0){
            if(kstrcmp(arg1,"psx")==0)       gl_real_demo_psx();
            else if(kstrcmp(arg1,"doom")==0)  gl_real_demo_doom();
            else if(kstrcmp(arg1,"cube")==0)  gl_real_demo_cube();
            else if(kstrcmp(arg1,"bench")==0)  gl_performance_benchmark();
            else if(kstrcmp(arg1,"multi")==0)  gl_multi_context_demo();
            else                              gl_real_demo_cube();
            tty_clear(); draw_header();
        }
        else if(kstrcmp(arg0,"engine")==0){
            if(kstrcmp(arg1,"psx")==0)       engine_psx();
            else if(kstrcmp(arg1,"doom")==0)  engine_doom();
            else out_print("Usage: engine psx | engine doom",ATTR_RED);
            tty_clear(); draw_header();
        }
        else if(kstrcmp(arg0,"makegame")==0){
            if(kstrcmp(arg1,"psx")==0)       makegame_psx();
            else if(kstrcmp(arg1,"doom")==0)  makegame_doom();
            else out_print("Usage: makegame psx | makegame doom",ATTR_RED);
        }
        else if(kstrcmp(arg0,"playgame")==0){
            if(kstrcmp(arg1,"psx")==0){       gl_real_demo_psx();  tty_clear(); draw_header(); }
            else if(kstrcmp(arg1,"doom")==0){ gl_real_demo_doom(); tty_clear(); draw_header(); }
            else out_print("Usage: playgame psx | playgame doom",ATTR_RED);
        }
        else if(kstrcmp(arg0,"sdk")==0){
            if(kstrcmp(arg1,"init")==0)        sdk_init_system();
            else if(kstrcmp(arg1,"build")==0)  sdk_build_project_real("psx-demo");
            else if(kstrcmp(arg1,"run")==0)    sdk_run_project_real("psx-demo");
            else if(kstrcmp(arg1,"status")==0) sdk_status_real();
            else out_print("Usage: sdk init | sdk build | sdk run | sdk status",ATTR_RED);
        }
        else if(kstrcmp(arg0,"exit")==0) running=0;
        else if(arg0[0]!='\0'){
            char msg[VGA_COLS]; int i=0,j=0;
            msg[i++]='\''; while(arg0[j]&&i<VGA_COLS-18) msg[i++]=arg0[j++];
            msg[i++]='\''; msg[i++]=' ';
            const char *e="is not recognized as a command.";
            while(*e&&i<VGA_COLS-1) {
                msg[i++]=*e++;
            }
            msg[i]='\0';
            out_print(msg,ATTR_RED);
        }
    }
}

/* ================================================================== */
/* Kernel entry point                                                */
/* ================================================================== */
void core_main(void){
    tty_cursor_enable(); tty_clear();
    boot_sequence();
    do_login();
    
    /* Show boot menu for game selection */
    ksdos_boot_menu();
    
    /* Initialize SDK system */
    ksdos_init_sdk_system();
    
    /* Enter shell */
    draw_shell();
    for(;;) __asm__ volatile("cli;hlt");
}
