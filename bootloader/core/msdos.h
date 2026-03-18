/* ================================================================
   KSDOS MS-DOS Compatible Command System
   Complete MS-DOS 6.22 compatible command implementation
   ================================================================ */

#ifndef KSDOS_MSDOS_H
#define KSDOS_MSDOS_H

/* MS-DOS Version Information */
#define MSDOS_VERSION_MAJOR    6
#define MSDOS_VERSION_MINOR    22
#define MSDOS_VERSION_PATCH    0

/* Command Structure */
typedef struct {
    const char* name;
    const char* description;
    const char* syntax;
    int (*handler)(int argc, char* argv[]);
    int internal;  /* 1 = internal command, 0 = external program */
} msdos_command_t;

/* File System Types */
typedef enum {
    FS_TYPE_FAT12 = 12,
    FS_TYPE_FAT16 = 16,
    FS_TYPE_FAT32 = 32,
    FS_TYPE_NTFS  = 1,
    FS_TYPE_EXT2  = 2
} fs_type_t;

/* File Attributes */
#define FILE_ATTR_READ_ONLY   0x01
#define FILE_ATTR_HIDDEN      0x02
#define FILE_ATTR_SYSTEM      0x04
#define FILE_ATTR_VOLUME_ID   0x08
#define FILE_ATTR_DIRECTORY   0x10
#define FILE_ATTR_ARCHIVE     0x20
#define FILE_ATTR_NORMAL      0x80

/* File System Entry */
typedef struct {
    char name[256];           /* File/directory name */
    char path[512];           /* Full path */
    unsigned long size;       /* File size in bytes */
    unsigned int attributes; /* File attributes */
    unsigned int date;        /* Creation date */
    unsigned int time;        /* Creation time */
    int is_directory;         /* 1 if directory, 0 if file */
    void* data;              /* File data pointer */
} fs_entry_t;

/* Drive Information */
typedef struct {
    char letter;              /* Drive letter (A, C, etc.) */
    fs_type_t type;          /* File system type */
    char label[12];          /* Volume label */
    unsigned long total_space; /* Total space in bytes */
    unsigned long free_space;  /* Free space in bytes */
    unsigned long cluster_size; /* Cluster size in bytes */
    int mounted;             /* 1 if mounted, 0 if not */
} drive_info_t;

/* Process Information */
typedef struct {
    unsigned int pid;        /* Process ID */
    char name[256];          /* Process name */
    unsigned int memory;     /* Memory usage */
    unsigned int parent_pid; /* Parent process ID */
    int active;              /* 1 if active, 0 if terminated */
} process_info_t;

/* System Information */
typedef struct {
    char cpu_vendor[16];     /* CPU vendor string */
    char cpu_model[64];      /* CPU model */
    float cpu_speed;         /* CPU speed in MHz */
    unsigned long total_memory; /* Total memory in KB */
    unsigned long free_memory;  /* Free memory in KB */
    int num_drives;          /* Number of drives */
    drive_info_t drives[26]; /* Drive information (A-Z) */
    int num_processes;       /* Number of active processes */
    process_info_t processes[64]; /* Process table */
} system_info_t;

/* Environment Variables */
#define MAX_ENV_VARS 256
typedef struct {
    char name[64];
    char value[256];
} env_var_t;

/* Command History */
#define CMD_HISTORY_SIZE 50
typedef struct {
    char commands[CMD_HISTORY_SIZE][512];
    int current;
    int count;
} cmd_history_t;

/* Batch File Processing */
#define BATCH_MAX_LINES 1000
#define BATCH_MAX_ARGS 10
typedef struct {
    char filename[256];
    char lines[BATCH_MAX_LINES][512];
    int current_line;
    int total_lines;
    char args[BATCH_MAX_ARGS][64];
    int arg_count;
    int echo_on;
    int active;
} batch_context_t;

/* Function Prototypes */

/* Command System */
int msdos_init(void);
int msdos_shutdown(void);
int msdos_execute_command(const char* command_line);
int msdos_register_command(const char* name, const char* desc, const char* syntax, 
                          int (*handler)(int, char**), int internal);
int msdos_unregister_command(const char* name);
void msdos_list_commands(void);
void msdos_show_help(const char* command);

/* File System */
int fs_init(void);
int fs_shutdown(void);
int fs_format_drive(char drive, fs_type_t type, const char* label);
int fs_mount_drive(char drive, const char* device);
int fs_unmount_drive(char drive);
int fs_create_directory(const char* path);
int fs_remove_directory(const char* path);
int fs_create_file(const char* path);
int fs_remove_file(const char* path);
int fs_copy_file(const char* src, const char* dst);
int fs_move_file(const char* src, const char* dst);
fs_entry_t* fs_find_entry(const char* path);
int fs_list_directory(const char* path, fs_entry_t** entries, int* count);
int fs_get_file_info(const char* path, fs_entry_t* info);
int fs_set_file_attributes(const char* path, unsigned int attributes);
int fs_get_drive_info(char drive, drive_info_t* info);

/* System Management */
int sys_init(void);
int sys_shutdown(void);
int sys_get_info(system_info_t* info);
int sys_get_process_info(unsigned int pid, process_info_t* info);
int sys_kill_process(unsigned int pid);
int sys_create_process(const char* name, unsigned int* pid);
int sys_set_environment(const char* name, const char* value);
char* sys_get_environment(const char* name);
int sys_list_environment(env_var_t** vars, int* count);
int sys_get_memory_usage(unsigned long* total, unsigned long* free);
int sys_get_cpu_usage(float* usage);

/* Command Handlers */
int cmd_dir(int argc, char* argv[]);
int cmd_cd(int argc, char* argv[]);
int cmd_md(int argc, char* argv[]);
int cmd_rd(int argc, char* argv[]);
int cmd_copy(int argc, char* argv[]);
int cmd_move(int argc, char* argv[]);
int cmd_del(int argc, char* argv[]);
int cmd_type(int argc, char* argv[]);
int cmd_attrib(int argc, char* argv[]);
int cmd_format(int argc, char* argv[]);
int cmd_label(int argc, char* argv[]);
int cmd_vol(int argc, char* argv[]);
int cmd_chkdsk(int argc, char* argv[]);
int cmd_defrag(int argc, char* argv[]);
int cmd_scanreg(int argc, char* argv[]);
int cmd_sys(int argc, char* argv[]);
int cmd_command(int argc, char* argv[]);
int cmd_exit(int argc, char* argv[]);
int cmd_ver(int argc, char* argv[]);
int cmd_cls(int argc, char* argv[]);
int cmd_date(int argc, char* argv[]);
int cmd_time(int argc, char* argv[]);
int cmd_path(int argc, char* argv[]);
int cmd_prompt(int argc, char* argv[]);
int cmd_set(int argc, char* argv[]);
int cmd_echo(int argc, char* argv[]);
int cmd_if(int argc, char* argv[]);
int cmd_goto(int argc, char* argv[]);
int cmd_call(int argc, char* argv[]);
int cmd_for(int argc, char* argv[]);
int cmd_pause(int argc, char* argv[]);
int cmd_rem(int argc, char* argv[]);
int cmd_break(int argc, char* argv[]);
int cmd_verify(int argc, char* argv[]);
int cmd_more(int argc, char* argv[]);
int cmd_find(int argc, char* argv[]);
int cmd_sort(int argc, char* argv[]);
int cmd_tree(int argc, char* argv[]);
int cmd_xcopy(int argc, char* argv[]);
int cmd_deltree(int argc, char* argv[]);
int cmd_mem(int argc, char* argv[]);
int cmd_tasklist(int argc, char* argv[]);
int cmd_taskkill(int argc, char* argv[]);
int cmd_system(int argc, char* argv[]);
int cmd_shutdown(int argc, char* argv[]);
int cmd_reboot(int argc, char* argv[]);
int cmd_help(int argc, char* argv[]);

/* Batch File Processing */
int batch_init(void);
int batch_execute(const char* filename);
int batch_execute_line(const char* line);
int batch_set_args(int argc, char* argv[]);
int batch_set_echo(int on);
int batch_is_active(void);
void batch_stop(void);

/* Command Line Processing */
int parse_command_line(const char* line, char* argv[], int max_args);
char* expand_environment_vars(const char* input);
char* expand_wildcards(const char* pattern);
int check_file_existence(const char* filename);

/* Utility Functions */
char* get_current_directory(void);
int set_current_directory(const char* path);
char* get_current_drive(void);
int set_current_drive(char drive);
char* format_file_size(unsigned long size);
char* format_date(unsigned int date);
char* format_time(unsigned int time);
int is_absolute_path(const char* path);
char* make_absolute_path(const char* path);
char* make_relative_path(const char* path, const char* base);

/* Error Codes */
#define MSDOS_SUCCESS           0
#define MSDOS_ERROR_FILE_NOT_FOUND   1
#define MSDOS_ERROR_PATH_NOT_FOUND   2
#define MSDOS_ERROR_ACCESS_DENIED    3
#define MSDOS_ERROR_NOT_ENOUGH_MEMORY 4
#define MSDOS_ERROR_INVALID_PARAMETER 5
#define MSDOS_ERROR_DRIVE_NOT_READY  6
#define MSDOS_ERROR_WRITE_PROTECTED  7
#define MSDOS_ERROR_BAD_COMMAND_FORMAT 8
#define MSDOS_ERROR_FILE_EXISTS      9
#define MSDOS_ERROR_DIRECTORY_NOT_EMPTY 10
#define MSDOS_ERROR_INVALID_DRIVE    11
#define MSDOS_ERROR_NO_SUCH_DRIVE     12
#define MSDOS_ERROR_DISK_FULL        13
#define MSDOS_ERROR_TOO_MANY_FILES   14
#define MSDOS_ERROR_PROCESS_NOT_FOUND 15
#define MSDOS_ERROR_ACCESS_DENIED_PROCESS 16

#endif /* KSDOS_MSDOS_H */
