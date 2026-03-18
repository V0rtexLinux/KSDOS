/* ================================================================
   KSDOS SDK Integration Header
   Real SDK implementation for PS1 and DOOM development
   ================================================================ */

#ifndef KSDOS_SDK_H
#define KSDOS_SDK_H

/* SDK Detection and Configuration */
#define KSDOS_SDK_VERSION_MAJOR 1
#define KSDOS_SDK_VERSION_MINOR 0
#define KSDOS_SDK_VERSION_PATCH 0

/* SDK Paths */
#define PS1_SDK_PATH    "/sdk/psyq"
#define DOOM_SDK_PATH   "/sdk/gold4"
#define GAMES_PATH      "/games"

/* PS1 SDK Configuration */
#define PS1_SDK_VERSION      "4.7"
#define PS1_TOOLCHAIN        "mipsel-none-elf-gcc 12.3.0"
#define PS1_MEMORY_BASE      0x80010000
#define PS1_RAM_SIZE         0x200000  /* 2MB */
#define PS1_VRAM_BASE        0x00000000
#define PS1_VRAM_SIZE        0x00100000  /* 1MB */

/* DOOM SDK Configuration */
#define DOOM_SDK_VERSION     "4.0"
#define DOOM_TOOLCHAIN       "djgpp gcc 12.3 + GNU gold"
#define DOOM_MEMORY_BASE     0x00000000
#define DOOM_VGA_MODE        0x13      /* 320x200x256 */
#define DOOM_VGA_WIDTH       320
#define DOOM_VGA_HEIGHT      256
#define DOOM_VGA_FRAMEBUFFER 0xA0000

/* SDK Status */
typedef enum {
    SDK_STATUS_UNKNOWN = 0,
    SDK_STATUS_AVAILABLE,
    SDK_STATUS_LOADING,
    SDK_STATUS_READY,
    SDK_STATUS_ERROR
} sdk_status_t;

/* SDK Information Structure */
typedef struct {
    const char* name;
    const char* version;
    const char* toolchain;
    const char* path;
    sdk_status_t status;
    unsigned int memory_base;
    unsigned int memory_size;
} sdk_info_t;

/* Game Project Structure */
typedef struct {
    const char* name;
    const char* type;        /* "PS1" or "DOOM" */
    const char* main_file;
    const char* executable;
    sdk_status_t status;
    unsigned int build_time;
} game_project_t;

/* Function Prototypes */
int ksdos_detect_sdks(void);
int ksdos_init_sdk_system(void);
sdk_info_t* ksdos_get_sdk_info(const char* sdk_name);
int ksdos_load_game_project(const char* project_path);
int ksdos_build_game(const char* project_name);
int ksdos_run_game(const char* project_name);
void ksdos_list_available_projects(void);
void ksdos_show_sdk_status(void);

/* SDK Integration Functions */
int ksdos_ps1_init(void);
int ksdos_doom_init(void);
int ksdos_ps1_compile_project(const char* project);
int ksdos_doom_compile_project(const char* project);

/* File System Integration */
int ksdos_mount_sdk_paths(void);
int ksdos_scan_game_directory(void);
char* ksdos_read_file(const char* path);
int ksdos_write_file(const char* path, const char* data);

/* Build System Integration */
typedef struct {
    char command[256];
    char output[512];
    int return_code;
    int execution_time;
} build_result_t;

build_result_t ksdos_execute_build(const char* command);
int ksdos_parse_makefile(const char* makefile_path);

/* Error Codes */
#define KSDOS_SDK_SUCCESS        0
#define KSDOS_SDK_ERROR_NOTFOUND -1
#define KSDOS_SDK_ERROR_LOAD    -2
#define KSDOS_SDK_ERROR_BUILD   -3
#define KSDOS_SDK_ERROR_RUNTIME -4

#endif /* KSDOS_SDK_H */
