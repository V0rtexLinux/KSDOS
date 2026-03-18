/* KSDOS - MS-DOS style kernel
   VGA text mode 80x25 (0xB8000)
   Complete keyboard driver with US mapping */

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

/* Keyboard port addresses */
#define KEYBOARD_DATA    0x60
#define KEYBOARD_STATUS  0x64
#define KEYBOARD_CMD     0x64

/* Keyboard status bits */
#define KBD_STATUS_OUTPUT_FULL  0x01
#define KBD_STATUS_INPUT_FULL   0x02

/* Keyboard commands */
#define KBD_CMD_LED         0xED
#define KBD_CMD_ENABLE      0xF4
#define KBD_CMD_DISABLE     0xF5
#define KBD_CMD_RESET       0xFF

/* Special key codes */
#define KEY_ESC        0x01
#define KEY_BACKSPACE  0x0E
#define KEY_TAB        0x0F
#define KEY_ENTER      0x1C
#define KEY_LCTRL      0x1D
#define KEY_LSHIFT     0x2A
#define KEY_RSHIFT     0x36
#define KEY_LALT       0x38
#define KEY_CAPSLOCK   0x3A
#define KEY_F1         0x3B
#define KEY_F2         0x3C
#define KEY_F3         0x3D
#define KEY_F4         0x3E
#define KEY_F5         0x3F
#define KEY_F6         0x40
#define KEY_F7         0x41
#define KEY_F8         0x42
#define KEY_F9         0x43
#define KEY_F10        0x44
#define KEY_F11        0x57
#define KEY_F12        0x58
#define KEY_NUMLOCK    0x45
#define KEY_SCROLLLOCK 0x46
#define KEY_HOME       0x47
#define KEY_UP         0x48
#define KEY_PGUP       0x49
#define KEY_KP_MINUS   0x4A
#define KEY_LEFT       0x4B
#define KEY_CENTER     0x4C
#define KEY_RIGHT      0x4D
#define KEY_KP_PLUS    0x4E
#define KEY_END        0x4F
#define KEY_DOWN       0x50
#define KEY_PGDN       0x51
#define KEY_INS        0x52
#define KEY_DEL        0x53

/* Function prototypes */
static void outb(unsigned short port, unsigned char val);
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
static int strcmp(const char *s1, const char *s2);
static void tty_puts_center(int row, const char *s, unsigned char attr);
static void tty_hline(int row, unsigned char attr);
static void read_line(int row, int col, char *buffer, int maxlen, int mask);
static void do_login(void);
static void boot_sequence(void);
static void draw_shell(void);

/* ------------------------------------------------------------------ */
/*  Keyboard state                                                     */
/* ------------------------------------------------------------------ */
static struct {
    unsigned int shift_pressed : 1;
    unsigned int ctrl_pressed : 1;
    unsigned int alt_pressed : 1;
    unsigned int caps_lock : 1;
    unsigned int num_lock : 1;
    unsigned int scroll_lock : 1;
    unsigned int extended : 1;
} kbd_state = {0};

/* US Keyboard layout - normal (unshifted) */
static const unsigned char kbd_us[128] = {
    0,    KEY_ESC, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
    KEY_LCTRL, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
    KEY_LSHIFT, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', KEY_RSHIFT,
    '*', KEY_LALT, ' ', KEY_CAPSLOCK, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5,
    KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_NUMLOCK, KEY_SCROLLLOCK,
    KEY_HOME, KEY_UP, KEY_PGUP, KEY_KP_MINUS, KEY_LEFT, KEY_CENTER, KEY_RIGHT,
    KEY_KP_PLUS, KEY_END, KEY_DOWN, KEY_PGDN, KEY_INS, KEY_DEL, 0, 0, 0,
    KEY_F11, KEY_F12
};

/* US Keyboard layout - shifted */
static const unsigned char kbd_us_shift[128] = {
    0,    KEY_ESC, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b',
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n',
    KEY_LCTRL, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~',
    KEY_LSHIFT, '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', KEY_RSHIFT,
    '*', KEY_LALT, ' ', KEY_CAPSLOCK, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5,
    KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_NUMLOCK, KEY_SCROLLLOCK,
    KEY_HOME, KEY_UP, KEY_PGUP, KEY_KP_MINUS, KEY_LEFT, KEY_CENTER, KEY_RIGHT,
    KEY_KP_PLUS, KEY_END, KEY_DOWN, KEY_PGDN, KEY_INS, KEY_DEL, 0, 0, 0,
    KEY_F11, KEY_F12
};

/* ------------------------------------------------------------------ */
/*  Low-level helpers                                                 */
/* ------------------------------------------------------------------ */

static void outb(unsigned short port, unsigned char val)
{
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

static unsigned char inb(unsigned short port)
{
    unsigned char val;
    __asm__ volatile ("inb %1, %0" : "=a"(val) : "Nd"(port));
    return val;
}

static void delay(unsigned int count)
{
    volatile unsigned int i;
    for (i = 0; i < count; i++)
        __asm__ volatile ("nop");
}

/* ------------------------------------------------------------------ */
/*  Keyboard driver functions                                         */
/* ------------------------------------------------------------------ */

/* Wait for keyboard controller to be ready to send command */
static void kbd_wait_write(void)
{
    while (inb(KEYBOARD_STATUS) & 2)
        ;
}

/* Wait for keyboard controller to have data ready */
static void kbd_wait_read(void)
{
    while (!(inb(KEYBOARD_STATUS) & 1))
        ;
}

/* Send command to keyboard */
static void kbd_send_cmd(unsigned char cmd)
{
    kbd_wait_write();
    outb(KEYBOARD_CMD, cmd);
}

/* Send data to keyboard */
static void kbd_send_data(unsigned char data)
{
    kbd_wait_write();
    outb(KEYBOARD_DATA, data);
}

/* Read data from keyboard */
static unsigned char kbd_read_data(void)
{
    kbd_wait_read();
    return inb(KEYBOARD_DATA);
}

/* Set keyboard LEDs based on lock states */
static void kbd_set_leds(void)
{
    unsigned char led_status = 0;
    
    if (kbd_state.scroll_lock) led_status |= 1;
    if (kbd_state.num_lock) led_status |= 2;
    if (kbd_state.caps_lock) led_status |= 4;
    
    kbd_send_data(KBD_CMD_LED);
    kbd_read_data();  /* Read ACK */
    kbd_send_data(led_status);
    kbd_read_data();  /* Read ACK */
}

/* Initialize keyboard */
static void kbd_init(void)
{
    unsigned char ack;
    
    /* Disable keyboard during initialization */
    kbd_send_cmd(0xAD);  /* Disable keyboard interface */
    delay(1000);
    
    /* Flush output buffer */
    while (inb(KEYBOARD_STATUS) & 1)
        inb(KEYBOARD_DATA);
    
    /* Reset keyboard */
    kbd_send_cmd(0xFF);  /* Reset */
    ack = kbd_read_data();
    
    if (ack != 0xFA) {  /* Should receive ACK (0xFA) */
        /* Reset failed, but continue anyway */
    }
    
    /* Wait for self-test result */
    ack = kbd_read_data();
    
    /* Enable keyboard */
    kbd_send_cmd(0xAE);  /* Enable keyboard interface */
    delay(1000);
    
    /* Set default typematic rate/delay */
    kbd_send_data(0xF3);  /* Set typematic */
    kbd_read_data();      /* Read ACK */
    kbd_send_data(0x00);  /* 500ms, 30cps */
    kbd_read_data();      /* Read ACK */
    
    /* Enable scanning */
    kbd_send_data(0xF4);
    kbd_read_data();      /* Read ACK */
    
    /* Set keyboard LEDs */
    kbd_set_leds();
}

/* Process a scancode and return the corresponding character */
static int kbd_process_scancode(unsigned char scancode, unsigned char *ch)
{
    int is_break = (scancode & 0x80) ? 1 : 0;
    unsigned char key = scancode & 0x7F;
    unsigned char result = 0;
    
    /* Handle extended (E0) prefix - we'll simulate for simplicity */
    if (scancode == 0xE0) {
        kbd_state.extended = 1;
        return 0;
    }
    
    /* Handle key press (make) */
    if (!is_break) {
        /* Update modifier states */
        switch (key) {
            case KEY_LSHIFT:
            case KEY_RSHIFT:
                kbd_state.shift_pressed = 1;
                return 0;
            case KEY_LCTRL:
                kbd_state.ctrl_pressed = 1;
                return 0;
            case KEY_LALT:
                kbd_state.alt_pressed = 1;
                return 0;
            case KEY_CAPSLOCK:
                kbd_state.caps_lock = !kbd_state.caps_lock;
                kbd_set_leds();
                return 0;
            case KEY_NUMLOCK:
                kbd_state.num_lock = !kbd_state.num_lock;
                kbd_set_leds();
                return 0;
            case KEY_SCROLLLOCK:
                kbd_state.scroll_lock = !kbd_state.scroll_lock;
                kbd_set_leds();
                return 0;
            default:
                break;
        }
        
        /* Get character from appropriate layout */
        if (kbd_state.shift_pressed) {
            result = kbd_us_shift[key];
        } else {
            result = kbd_us[key];
        }
        
        /* Handle caps lock for letters */
        if (kbd_state.caps_lock && result >= 'a' && result <= 'z') {
            result -= 32;  /* Convert to uppercase */
        } else if (kbd_state.caps_lock && result >= 'A' && result <= 'Z') {
            result += 32;  /* Convert to lowercase */
        }
        
        /* Handle extended keys (arrows, etc.) */
        if (kbd_state.extended) {
            switch (key) {
                case KEY_UP:    result = 0xE0; break;
                case KEY_DOWN:  result = 0xE1; break;
                case KEY_LEFT:  result = 0xE2; break;
                case KEY_RIGHT: result = 0xE3; break;
                case KEY_HOME:  result = 0xE4; break;
                case KEY_END:   result = 0xE5; break;
                case KEY_PGUP:  result = 0xE6; break;
                case KEY_PGDN:  result = 0xE7; break;
                case KEY_INS:   result = 0xE8; break;
                case KEY_DEL:   result = 0xE9; break;
            }
        }
        
        *ch = result;
        kbd_state.extended = 0;
        return 1;
    } 
    /* Handle key release (break) */
    else {
        switch (key) {
            case KEY_LSHIFT:
            case KEY_RSHIFT:
                kbd_state.shift_pressed = 0;
                break;
            case KEY_LCTRL:
                kbd_state.ctrl_pressed = 0;
                break;
            case KEY_LALT:
                kbd_state.alt_pressed = 0;
                break;
        }
        kbd_state.extended = 0;
        return 0;
    }
}

/* Read a single character from keyboard (blocking) */
static unsigned char kbd_getchar(void)
{
    unsigned char scancode;
    unsigned char ch;
    
    while (1) {
        /* Wait for keyboard interrupt or polling */
        scancode = kbd_read_data();
        
        if (kbd_process_scancode(scancode, &ch)) {
            if (ch >= 0x20 && ch <= 0x7E) {  /* Printable ASCII */
                return ch;
            } else {
                /* Return special key codes */
                return ch;
            }
        }
    }
}

/* Check if a key is available (non-blocking) */
static int kbd_key_available(void)
{
    return (inb(KEYBOARD_STATUS) & 1) ? 1 : 0;
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
/*  Simple string length                                              */
/* ------------------------------------------------------------------ */
static int slen(const char *s)
{
    int n = 0;
    while (s[n]) n++;
    return n;
}

/* ------------------------------------------------------------------ */
/*  String comparison                                                 */
/* ------------------------------------------------------------------ */
static int strcmp(const char *s1, const char *s2)
{
    while (*s1 && *s1 == *s2) {
        s1++;
        s2++;
    }
    return *(unsigned char*)s1 - *(unsigned char*)s2;
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
/*  Read a line from keyboard with optional echo masking              */
/* ------------------------------------------------------------------ */
static void read_line(int row, int col, char *buffer, int maxlen, int mask)
{
    int pos = 0;
    unsigned char c;
    
    buffer[0] = '\0';
    tty_set_cursor(col, row);
    
    while (1) {
        c = kbd_getchar();
        
        if (c == '\n' || c == KEY_ENTER) {  /* Enter key */
            buffer[pos] = '\0';
            break;
        }
        else if (c == '\b' || c == KEY_BACKSPACE) {  /* Backspace */
            if (pos > 0) {
                pos--;
                tty_put(col + pos, row, ' ', ATTR_NORMAL);
                tty_set_cursor(col + pos, row);
            }
        }
        else if (c >= 0x20 && c <= 0x7E) {  /* Printable characters */
            if (pos < maxlen - 1) {
                buffer[pos] = c;
                if (!mask) {
                    tty_put(col + pos, row, c, ATTR_NORMAL);
                } else {
                    tty_put(col + pos, row, '*', ATTR_NORMAL);
                }
                pos++;
                tty_set_cursor(col + pos, row);
            }
        }
        /* Handle arrow keys, etc. if needed */
    }
    
    buffer[pos] = '\0';
}

/* ------------------------------------------------------------------ */
/*  Login screen with user/password authentication                    */
/* ------------------------------------------------------------------ */
#define USERNAME  "ksdos"
#define PASSWORD  "ksdos"

static void do_login(void)
{
    int attempts = 0;
    char username[32];
    char password[32];

    /* Initialize keyboard */
    kbd_init();

    while (attempts < 3) {
        tty_clear();

        tty_puts_center(10, "KSDOS Login", ATTR_BRIGHT);
        tty_puts(5, 12, "Username: ", ATTR_NORMAL);
        read_line(12, 5 + 10, username, sizeof(username), 0);
        
        tty_puts(5, 13, "Password: ", ATTR_NORMAL);
        read_line(13, 5 + 10, password, sizeof(password), 1);

        if (strcmp(username, USERNAME) == 0 && strcmp(password, PASSWORD) == 0) {
            /* success – proceed to shell */
            return;
        } else {
            attempts++;
            tty_puts_center(15, "Invalid username or password. Press any key to retry.", ATTR_RED);
            kbd_getchar();  /* Wait for key press */
        }
    }

    /* Too many failed attempts */
    tty_clear();
    tty_puts_center(12, "System locked. Too many failed attempts.", ATTR_RED);
    for (;;)
        __asm__ volatile ("cli; hlt");
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

    tty_puts(0, r++, "Initializing keyboard...", ATTR_NORMAL);
    delay(8000000);
}

/* ------------------------------------------------------------------ */
/*  Main desktop (MS-DOS shell)                                       */
/* ------------------------------------------------------------------ */
static void draw_shell(void)
{
    char cmd[128];
    int running = 1;
    
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
    tty_puts(0, 12, "  Type 'help' for available commands.", ATTR_GREEN);

    /* ---- Separator ---- */
    tty_hline(13, ATTR_NORMAL);

    /* Simple command loop */
    while (running) {
        /* ---- Prompt ---- */
        tty_puts(0, 15, "C:\\>", ATTR_NORMAL);
        tty_fill(4, 15, 70, ' ', ATTR_NORMAL);  /* Clear command area */
        
        /* Read command */
        read_line(15, 4, cmd, sizeof(cmd), 0);
        
        /* Process commands */
        if (strcmp(cmd, "help") == 0) {
            tty_puts(0, 16, "Available commands: help, cls, time, date, ver, exit", ATTR_CYAN);
            delay(8000000);
            tty_fill(0, 16, 80, ' ', ATTR_NORMAL);  /* Clear help line */
        }
        else if (strcmp(cmd, "cls") == 0) {
            draw_shell();  /* Redraw shell (simplified) */
            return;
        }
        else if (strcmp(cmd, "ver") == 0) {
            tty_puts(0, 16, "KSDOS Version 1.0 (KernelSoft Disk Operating System)", ATTR_CYAN);
            delay(8000000);
            tty_fill(0, 16, 80, ' ', ATTR_NORMAL);
        }
        else if (strcmp(cmd, "exit") == 0) {
            running = 0;
        }
        else if (cmd[0] != '\0') {
            tty_puts(0, 16, "Bad command or file name", ATTR_RED);
            delay(8000000);
            tty_fill(0, 16, 80, ' ', ATTR_NORMAL);
        }
    }
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

    /* Require authentication before showing the shell */
    do_login();

    /* Render the final MS-DOS style shell */
    draw_shell();

    /* Halt the CPU */
    for (;;)
        __asm__ volatile ("cli; hlt");
}