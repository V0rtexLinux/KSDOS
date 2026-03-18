/* ================================================================
   KSDOS Real File System Implementation
   FAT12/16/32 compatible file system with virtual disk support
   ================================================================ */

#ifndef KSDOS_FILESYSTEM_H
#define KSDOS_FILESYSTEM_H

#include <stdint.h>
#include <time.h>

/* File System Types */
#define FS_TYPE_FAT12    0x01
#define FS_TYPE_FAT16    0x04
#define FS_TYPE_FAT32    0x0B
#define FS_TYPE_NTFS     0x07
#define FS_TYPE_EXT2     0x83
#define FS_TYPE_ISO9660  0x96

/* File System Limits */
#define MAX_PATH_LENGTH      260
#define MAX_FILENAME_LENGTH  255
#define MAX_FILE_SIZE        (4LL * 1024 * 1024 * 1024)  /* 4GB */
#define MAX_FILES_PER_DIR    65536
#define MAX_OPEN_FILES       256
#define SECTOR_SIZE          512
#define CLUSTER_SIZE_MIN     512
#define CLUSTER_SIZE_MAX     65536

/* FAT Entry Values */
#define FAT_FREE_CLUSTER     0x0000
#define FAT_BAD_CLUSTER      0xFFF7
#define FAT_END_OF_CHAIN     0xFFFF
#define FAT12_END_OF_CHAIN   0x0FFF
#define FAT32_END_OF_CHAIN   0x0FFFFFFF

/* File Attributes */
#define ATTR_READ_ONLY       0x01
#define ATTR_HIDDEN          0x02
#define ATTR_SYSTEM          0x04
#define ATTR_VOLUME_ID       0x08
#define ATTR_DIRECTORY       0x10
#define ATTR_ARCHIVE         0x20
#define ATTR_DEVICE          0x40
#define ATTR_NORMAL          0x80
#define ATTR_TEMPORARY       0x100
#define ATTR_SPARSE_FILE     0x200
#define ATTR_REPARSE_POINT   0x400
#define ATTR_COMPRESSED      0x800
#define ATTR_OFFLINE         0x1000
#define ATTR_NOT_CONTENT_INDEXED 0x2000
#define ATTR_ENCRYPTED       0x4000

/* File Time/Date Format */
typedef struct {
    uint16_t year;    /* 1980-2107 */
    uint8_t month;    /* 1-12 */
    uint8_t day;      /* 1-31 */
    uint8_t hour;     /* 0-23 */
    uint8_t minute;   /* 0-59 */
    uint8_t second;   /* 0-59 (0-29 for 2-second precision) */
} fs_time_t;

/* Directory Entry Structure (FAT) */
typedef struct {
    char name[11];              /* 8.3 filename */
    uint8_t attributes;         /* File attributes */
    uint8_t reserved;           /* Reserved */
    uint8_t creation_time_tenth;/* Creation time (tenths) */
    uint16_t creation_time;     /* Creation time */
    uint16_t creation_date;     /* Creation date */
    uint16_t last_access_date;  /* Last access date */
    uint16_t first_cluster_hi;  /* High word of first cluster */
    uint16_t write_time;        /* Last write time */
    uint16_t write_date;        /* Last write date */
    uint16_t first_cluster_lo;  /* Low word of first cluster */
    uint32_t file_size;         /* File size in bytes */
} __attribute__((packed)) fat_dir_entry_t;

/* Long Filename Entry Structure */
typedef struct {
    uint8_t sequence;           /* Sequence number */
    uint16_t name1[5];          /* First 5 characters */
    uint8_t attributes;         /* Must be ATTR_READ_ONLY | ATTR_HIDDEN | ATTR_SYSTEM | ATTR_VOLUME_ID */
    uint8_t reserved1;          /* Always 0 */
    uint8_t checksum;           /* Checksum of 8.3 name */
    uint16_t name2[6];          /* Next 6 characters */
    uint16_t first_cluster;     /* Always 0 */
    uint16_t name3[2];          /* Last 2 characters */
} __attribute__((packed)) lfn_entry_t;

/* Volume Boot Record (FAT12/16) */
typedef struct {
    uint8_t jump_boot[3];       /* Jump instruction */
    char oem_name[8];           /* OEM name */
    uint16_t bytes_per_sector;  /* Bytes per sector */
    uint8_t sectors_per_cluster;/* Sectors per cluster */
    uint16_t reserved_sectors;  /* Reserved sectors */
    uint8_t num_fats;           /* Number of FATs */
    uint16_t root_entries;      /* Root directory entries */
    uint16_t total_sectors_16;  /* Total sectors (16-bit) */
    uint8_t media_type;         /* Media type */
    uint16_t fat_size_16;       /* FAT size (16-bit) */
    uint16_t sectors_per_track; /* Sectors per track */
    uint16_t num_heads;         /* Number of heads */
    uint32_t hidden_sectors;    /* Hidden sectors */
    uint32_t total_sectors_32;  /* Total sectors (32-bit) */
    /* FAT32 specific fields follow */
} __attribute__((packed)) fat_boot_sector_t;

/* Volume Boot Record (FAT32) */
typedef struct {
    uint8_t jump_boot[3];       /* Jump instruction */
    char oem_name[8];           /* OEM name */
    uint16_t bytes_per_sector;  /* Bytes per sector */
    uint8_t sectors_per_cluster;/* Sectors per cluster */
    uint16_t reserved_sectors;  /* Reserved sectors */
    uint8_t num_fats;           /* Number of FATs */
    uint16_t root_entries;      /* Root directory entries (0 for FAT32) */
    uint16_t total_sectors_16;  /* Total sectors (16-bit) */
    uint8_t media_type;         /* Media type */
    uint16_t fat_size_16;       /* FAT size (16-bit, 0 for FAT32) */
    uint16_t sectors_per_track; /* Sectors per track */
    uint16_t num_heads;         /* Number of heads */
    uint32_t hidden_sectors;    /* Hidden sectors */
    uint32_t total_sectors_32;  /* Total sectors (32-bit) */
    uint32_t fat_size_32;       /* FAT size (32-bit) */
    uint16_t ext_flags;         /* Extended flags */
    uint16_t fs_ver;            /* File system version */
    uint32_t root_cluster;      /* Root directory cluster */
    uint16_t fs_info;           /* File system info sector */
    uint16_t backup_boot;       /* Backup boot sector */
    uint8_t reserved[12];       /* Reserved */
    uint8_t drive_number;       /* Drive number */
    uint8_t reserved1;          /* Reserved */
    uint8_t boot_signature;     /* Boot signature */
    uint32_t volume_id;         /* Volume serial number */
    char volume_label[11];      /* Volume label */
    char fs_type[8];            /* File system type */
    uint8_t boot_code[420];     /* Boot code */
    uint16_t boot_signature_55aa;/* Boot signature */
} __attribute__((packed)) fat32_boot_sector_t;

/* File Handle Structure */
typedef struct {
    int used;                   /* 1 if in use, 0 if free */
    char filename[MAX_PATH_LENGTH]; /* Full file path */
    uint8_t* data;             /* File data pointer */
    uint32_t size;              /* File size */
    uint32_t position;          /* Current position */
    uint32_t first_cluster;     /* First cluster */
    uint32_t current_cluster;   /* Current cluster */
    uint8_t mode;               /* File mode (read/write) */
    uint8_t attributes;         /* File attributes */
    fs_time_t creation_time;    /* Creation time */
    fs_time_t modification_time;/* Modification time */
    fs_time_t access_time;      /* Last access time */
} file_handle_t;

/* Directory Structure */
typedef struct {
    char path[MAX_PATH_LENGTH]; /* Directory path */
    char name[MAX_FILENAME_LENGTH]; /* Directory name */
    uint32_t first_cluster;     /* First cluster */
    uint32_t parent_cluster;    /* Parent directory cluster */
    uint32_t size;              /* Size in bytes */
    uint32_t file_count;        /* Number of files */
    uint32_t subdirectory_count; /* Number of subdirectories */
    fs_time_t creation_time;    /* Creation time */
    fs_time_t modification_time;/* Modification time */
    uint8_t attributes;         /* Directory attributes */
} directory_t;

/* Virtual Disk Structure */
typedef struct {
    char filename[MAX_PATH_LENGTH]; /* Disk image filename */
    uint8_t* data;             /* Disk data */
    uint32_t size;              /* Disk size in bytes */
    uint32_t sector_count;      /* Number of sectors */
    uint16_t bytes_per_sector;  /* Bytes per sector */
    uint8_t sectors_per_cluster;/* Sectors per cluster */
    uint8_t fs_type;            /* File system type */
    uint32_t fat_start;         /* FAT start sector */
    uint32_t fat_size;          /* FAT size in sectors */
    uint32_t data_start;        /* Data area start sector */
    uint32_t root_start;        /* Root directory start */
    uint32_t root_size;         /* Root directory size */
    uint32_t cluster_count;     /* Total number of clusters */
    uint8_t mounted;            /* 1 if mounted, 0 if not */
    char label[12];             /* Volume label */
    uint32_t serial_number;     /* Volume serial number */
} virtual_disk_t;

/* File System Operations */
typedef struct {
    int (*read_sector)(uint32_t sector, uint8_t* buffer);
    int (*write_sector)(uint32_t sector, const uint8_t* buffer);
    int (*read_cluster)(uint32_t cluster, uint8_t* buffer);
    int (*write_cluster)(uint32_t cluster, const uint8_t* buffer);
    int (*allocate_cluster)(void);
    int (*free_cluster)(uint32_t cluster);
    int (*get_next_cluster)(uint32_t cluster, uint32_t* next);
    int (*set_next_cluster)(uint32_t cluster, uint32_t next);
} fs_operations_t;

/* File System Structure */
typedef struct {
    virtual_disk_t* disk;      /* Virtual disk */
    fs_operations_t ops;       /* File system operations */
    uint8_t type;               /* File system type */
    uint32_t root_cluster;      /* Root directory cluster */
    uint32_t current_dir;       /* Current directory cluster */
    char current_path[MAX_PATH_LENGTH]; /* Current path */
    file_handle_t open_files[MAX_OPEN_FILES]; /* Open file handles */
    int open_file_count;        /* Number of open files */
    uint8_t* fat;               /* FAT table */
    uint32_t fat_size;          /* FAT size in bytes */
    directory_t* root_dir;      /* Root directory */
    int initialized;            /* 1 if initialized */
} file_system_t;

/* Function Prototypes */

/* File System Initialization */
int fs_init(void);
int fs_shutdown(void);
int fs_mount_disk(const char* filename, char drive_letter);
int fs_unmount_disk(char drive_letter);
int fs_format_disk(const char* filename, uint32_t size, uint8_t fs_type, const char* label);

/* File Operations */
int fs_create_file(const char* path);
int fs_delete_file(const char* path);
int fs_open_file(const char* path, const char* mode, int* handle);
int fs_close_file(int handle);
int fs_read_file(int handle, void* buffer, uint32_t size, uint32_t* bytes_read);
int fs_write_file(int handle, const void* buffer, uint32_t size, uint32_t* bytes_written);
int fs_seek_file(int handle, int32_t offset, int whence);
int fs_tell_file(int handle, uint32_t* position);
int fs_eof_file(int handle);
int fs_flush_file(int handle);

/* Directory Operations */
int fs_create_directory(const char* path);
int fs_delete_directory(const char* path);
int fs_change_directory(const char* path);
int fs_list_directory(const char* path, directory_t* dir_info);
int fs_find_first_file(const char* path, const char* pattern, file_handle_t* handle);
int fs_find_next_file(file_handle_t* handle, char* filename);
int fs_find_close(file_handle_t* handle);

/* File Information */
int fs_get_file_info(const char* path, fs_time_t* creation, fs_time_t* modification, 
                     fs_time_t* access, uint32_t* size, uint8_t* attributes);
int fs_set_file_info(const char* path, const fs_time_t* creation, const fs_time_t* modification,
                     const fs_time_t* access, uint8_t* attributes);
int fs_copy_file(const char* src_path, const char* dst_path);
int fs_move_file(const char* src_path, const char* dst_path);

/* Disk Operations */
int fs_get_disk_info(char drive, uint32_t* total_space, uint32_t* free_space, 
                     uint32_t* cluster_size, char* label);
int fs_defragment_disk(char drive);
int fs_check_disk(char drive);
int fs_cleanup_disk(char drive);

/* Utility Functions */
int fs_parse_path(const char* path, char* drive, char* directory, char* filename);
int fs_validate_filename(const char* filename);
int fs_validate_path(const char* path);
char* fs_get_current_directory(void);
int fs_set_current_directory(const char* path);
char* fs_get_absolute_path(const char* path);
int fs_get_file_extension(const char* filename, char* extension);
int fs_remove_file_extension(char* filename);
int fs_canonicalize_path(char* path);

/* FAT Specific Functions */
int fat_init(file_system_t* fs);
int fat_read_fat(file_system_t* fs);
int fat_write_fat(file_system_t* fs);
int fat_get_next_cluster(file_system_t* fs, uint32_t cluster, uint32_t* next);
int fat_set_next_cluster(file_system_t* fs, uint32_t cluster, uint32_t next);
int fat_allocate_cluster(file_system_t* fs, uint32_t* cluster);
int fat_free_cluster_chain(file_system_t* fs, uint32_t start_cluster);
int fat_read_directory(file_system_t* fs, uint32_t cluster, directory_t* dir);
int fat_write_directory(file_system_t* fs, const directory_t* dir);
int fat_create_directory_entry(file_system_t* fs, const char* name, uint8_t attributes, 
                              uint32_t* cluster);
int fat_delete_directory_entry(file_system_t* fs, const char* name);
int fat_find_directory_entry(file_system_t* fs, const char* name, fat_dir_entry_t* entry);

/* Virtual Disk Functions */
int vd_create_disk(const char* filename, uint32_t size);
int vd_delete_disk(const char* filename);
int vd_open_disk(const char* filename, virtual_disk_t* disk);
int vd_close_disk(virtual_disk_t* disk);
int vd_read_sector(virtual_disk_t* disk, uint32_t sector, uint8_t* buffer);
int vd_write_sector(virtual_disk_t* disk, uint32_t sector, const uint8_t* buffer);
int vd_format_fat12(virtual_disk_t* disk, const char* label);
int vd_format_fat16(virtual_disk_t* disk, const char* label);
int vd_format_fat32(virtual_disk_t* disk, const char* label);

/* Error Codes */
#define FS_SUCCESS                 0
#define FS_ERROR_INVALID_PARAMETER 1
#define FS_ERROR_FILE_NOT_FOUND    2
#define FS_ERROR_PATH_NOT_FOUND    3
#define FS_ERROR_ACCESS_DENIED     4
#define FS_ERROR_NOT_ENOUGH_MEMORY 5
#define FS_ERROR_DISK_FULL         6
#define FS_ERROR_ALREADY_EXISTS    7
#define FS_ERROR_NOT_A_DIRECTORY   8
#define FS_ERROR_DIRECTORY_NOT_EMPTY 9
#define FS_ERROR_INVALID_DRIVE     10
#define FS_ERROR_NOT_READY         11
#define FS_ERROR_WRITE_PROTECTED   12
#define FS_ERROR_BAD_COMMAND_FORMAT 13
#define FS_ERROR_TOO_MANY_OPEN_FILES 14
#define FS_ERROR_FILE_TOO_LARGE    15
#define FS_ERROR_SECTOR_NOT_FOUND  16
#define FS_ERROR_CLUSTER_NOT_FOUND 17
#define FS_ERROR_FAT_CORRUPT       18
#define FS_ERROR_DISK_CORRUPT      19
#define FS_ERROR_UNSUPPORTED_OPERATION 20

/* File Modes */
#define FS_MODE_READ              "r"
#define FS_MODE_WRITE             "w"
#define FS_MODE_APPEND            "a"
#define FS_MODE_READ_PLUS         "r+"
#define FS_MODE_WRITE_PLUS        "w+"
#define FS_MODE_APPEND_PLUS       "a+"
#define FS_MODE_BINARY           "b"

/* Seek Origins */
#define FS_SEEK_SET              0
#define FS_SEEK_CUR              1
#define FS_SEEK_END              2

/* Drive Letters */
#define FS_DRIVE_A               'A'
#define FS_DRIVE_B               'B'
#define FS_DRIVE_C               'C'
#define FS_DRIVE_D               'D'
#define FS_DRIVE_E               'E'
#define FS_DRIVE_F               'F'
#define FS_DRIVE_G               'G'
#define FS_DRIVE_H               'H'
#define FS_DRIVE_I               'I'
#define FS_DRIVE_J               'J'
#define FS_DRIVE_K               'K'
#define FS_DRIVE_L               'L'
#define FS_DRIVE_M               'M'
#define FS_DRIVE_N               'N'
#define FS_DRIVE_O               'O'
#define FS_DRIVE_P               'P'
#define FS_DRIVE_Q               'Q'
#define FS_DRIVE_R               'R'
#define FS_DRIVE_S               'S'
#define FS_DRIVE_T               'T'
#define FS_DRIVE_U               'U'
#define FS_DRIVE_V               'V'
#define FS_DRIVE_W               'W'
#define FS_DRIVE_X               'X'
#define FS_DRIVE_Y               'Y'
#define FS_DRIVE_Z               'Z'

#endif /* KSDOS_FILESYSTEM_H */
