/* ================================================================
   KSDOS Game Loader - Boot-time game execution
   Automatically detects and runs games from /games directory
   ================================================================ */

#include "ksdos-sdk.h"
#include <stddef.h>
#include "kutils.h"

/* Boot menu configuration */
#define BOOT_MENU_TIMEOUT  50000000  /* 50 seconds */
#define MAX_BOOT_OPTIONS   8

typedef struct {
    const char* name;
    const char* description;
    void (*launch_func)(void);
    int is_sdk_game;
} boot_option_t;

/* Boot menu options */
static boot_option_t boot_options[MAX_BOOT_OPTIONS];
static int num_boot_options = 0;

/* External game launch functions */
extern void gl_demo_psx(void);
extern void gl_demo_doom(void);
extern void gl_demo_cube(void);

/* ================================================================ */
/* Boot Menu Functions                                               */
/* ================================================================ */

static void boot_menu_add_option(const char* name, const char* desc, void (*func)(void), int is_sdk) {
    if (num_boot_options < MAX_BOOT_OPTIONS) {
        boot_options[num_boot_options].name = name;
        boot_options[num_boot_options].description = desc;
        boot_options[num_boot_options].launch_func = func;
        boot_options[num_boot_options].is_sdk_game = is_sdk;
        num_boot_options++;
    }
}

static void boot_menu_init(void) {
    num_boot_options = 0;
    
    /* Add KSDOS shell (default) */
    boot_menu_add_option("KSDOS Shell", "Enter KSDOS command shell", NULL, 0);
    
    /* Add SDK game demos */
    boot_menu_add_option("PS1 Demo", "PlayStation 1 graphics demo", gl_demo_psx, 1);
    boot_menu_add_option("DOOM Demo", "DOOM-era raycaster demo", gl_demo_doom, 1);
    boot_menu_add_option("3D Cube", "OpenGL 3D rotating cube", gl_demo_cube, 0);
    
    /* Add SDK IDE screens */
    extern void engine_psx(void);
    extern void engine_doom(void);
    boot_menu_add_option("PS1 IDE", "PSYq Engine development IDE", engine_psx, 1);
    boot_menu_add_option("DOOM IDE", "GOLD4 Engine development IDE", engine_doom, 1);
}

static void boot_menu_display(void) {
    int i;
    char line[80];
    
    /* Clear screen and draw header */
    extern void tty_clear(void);
    extern void tty_fill(int, int, int, char, unsigned char);
    extern void tty_puts(int, int, const char*, unsigned char);
    extern void tty_puts_center(int, const char*, unsigned char);
    
    tty_clear();
    tty_fill(0, 0, 80, ' ', 0x70);  /* White on blue header */
    tty_puts_center(0, "KSDOS Game Loader - Boot Menu", 0x70);
    
    /* Display boot options */
    for (i = 0; i < num_boot_options; i++) {
        int pos = 0;
        
        /* Option number */
        line[pos++] = '1' + i;
        line[pos++] = '.';
        line[pos++] = ' ';
        
        /* Option name */
        const char* name = boot_options[i].name;
        while (*name && pos < 40) {
            line[pos++] = *name++;
        }
        
        /* Pad to column 40 */
        while (pos < 40) {
            line[pos++] = ' ';
        }
        
        /* Description */
        const char* desc = boot_options[i].description;
        while (*desc && pos < 78) {
            line[pos++] = *desc++;
        }
        
        line[pos] = '\0';
        
        /* Display with appropriate color */
        unsigned char attr = (boot_options[i].is_sdk_game) ? 0x0E : 0x07;  /* Yellow for SDK games */
        tty_puts(0, 3 + i, line, attr);
    }
    
    /* Instructions */
    tty_fill(0, 15, 80, ' ', 0x07);
    tty_puts_center(15, "Press 1-6 to select, or wait for automatic boot", 0x09);
    tty_puts_center(16, "Auto-boot in: 50 seconds", 0x0C);
    tty_puts_center(17, "ESC = Boot to KSDOS Shell", 0x07);
}

static int boot_menu_wait_input(void) {
    extern unsigned char kbd_getchar(void);
    extern int kbd_key_available(void);
    
    int countdown = 50;  /* 50 seconds */
    int iterations = 0;
    
    while (countdown > 0) {
        /* Check for keypress */
        if (kbd_key_available()) {
            unsigned char key = kbd_getchar();
            
            /* Number keys 1-6 */
            if (key >= '1' && key <= '6') {
                int selection = key - '1';
                if (selection < num_boot_options) {
                    return selection;
                }
            }
            /* ESC key */
            else if (key == 27) {
                return 0;  /* Boot to shell */
            }
        }
        
        /* Update countdown every second */
        iterations++;
        if (iterations >= 8000000) {  /* ~1 second */
            countdown--;
            iterations = 0;
            
            /* Update countdown display */
            char countdown_text[80];
            int pos = 0;
            
            const char* prefix = "Auto-boot in: ";
            while (*prefix) {
                countdown_text[pos++] = *prefix++;
            }
            
            /* Convert number to string */
            if (countdown < 10) {
                countdown_text[pos++] = ' ';
            }
            countdown_text[pos++] = '0' + (countdown / 10);
            countdown_text[pos++] = '0' + (countdown % 10);
            countdown_text[pos++] = ' ';
            countdown_text[pos++] = 's';
            countdown_text[pos++] = 'e';
            countdown_text[pos++] = 'c';
            countdown_text[pos++] = 'o';
            countdown_text[pos++] = 'n';
            countdown_text[pos++] = 'd';
            countdown_text[pos++] = 's';
            countdown_text[pos] = '\0';
            
            extern void tty_puts_center(int, const char*, unsigned char);
            tty_fill(0, 16, 80, ' ', 0x07);
            tty_puts_center(16, countdown_text, 0x0C);
        }
        
        delay(100);  /* Small delay */
    }
    
    return 0;  /* Default to shell */
}

/* ================================================================ */
/* Auto-detection of games                                           */
/* ================================================================ */

static int detect_available_games(void) {
    int detected = 0;
    
    /* Check for PS1 games */
    /* In a real implementation, this would scan /games/psx/ */
    detected++;
    
    /* Check for DOOM games */
    /* In a real implementation, this would scan /games/doom/ */
    detected++;
    
    return detected;
}

/* ================================================================ */
/* Main boot loader function                                         */
/* ================================================================ */

void ksdos_boot_menu(void) {
    /* Initialize boot menu */
    boot_menu_init();
    
    /* Detect available games */
    int games_found = detect_available_games();
    
    /* Display boot menu */
    boot_menu_display();
    
    /* Wait for user input or timeout */
    int selection = boot_menu_wait_input();
    
    /* Clear screen */
    extern void tty_clear(void);
    tty_clear();
    
    /* Launch selected option */
    if (selection >= 0 && selection < num_boot_options) {
        if (boot_options[selection].launch_func) {
            /* Display loading message */
            extern void tty_puts_center(int, const char*, unsigned char);
            tty_puts_center(12, "Loading...", 0x0E);
            
            /* Small delay for effect */
            delay(2000000);
            
            /* Launch the selected function */
            boot_options[selection].launch_func();
        }
        /* If no launch function, boot to shell (default behavior) */
    }
}

/* ================================================================ */
/* Boot-time game execution                                          */
/* ================================================================ */

void ksdos_auto_run_game(const char* game_type) {
    extern void tty_clear(void);
    extern void tty_puts_center(int, const char*, unsigned char);
    
    tty_clear();
    
    if (kstrcmp(game_type, "ps1") == 0) {
        tty_puts_center(12, "Auto-running PS1 Demo...", 0x0E);
        delay(2000000);
        gl_demo_psx();
    } else if (kstrcmp(game_type, "doom") == 0) {
        tty_puts_center(12, "Auto-running DOOM Demo...", 0x0E);
        delay(2000000);
        gl_demo_doom();
    } else if (kstrcmp(game_type, "cube") == 0) {
        tty_puts_center(12, "Auto-running 3D Cube Demo...", 0x0E);
        delay(2000000);
        gl_demo_cube();
    }
}
