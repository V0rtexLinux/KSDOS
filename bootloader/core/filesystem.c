/* ================================================================
   KSDOS Real File System Implementation
   FAT12/16/32 compatible file system with virtual disk support
   ================================================================ */

#include "filesystem.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

/* Global File System State */
static file_system_t file_systems[26];  /* A-Z drives */
static int fs_initialized = 0;
static char current_drive = 'C';
static char current_directory[MAX_PATH_LENGTH] = "C:\\";

/* Virtual Disk Storage */
#define MAX_VIRTUAL_DISKS 26
static virtual_disk_t virtual_disks[MAX_VIRTUAL_DISKS];
static int virtual_disk_count = 0;

/* Forward Declarations */
static int fat_read_sector_impl(uint32_t sector, uint8_t* buffer);
static int fat_write_sector_impl(uint32_t sector, const uint8_t* buffer);
static int fat_read_cluster_impl(uint32_t cluster, uint8_t* buffer);
static int fat_write_cluster_impl(uint32_t cluster, const uint8_t* buffer);
static int fat_allocate_cluster_impl(void);
static int fat_free_cluster_impl(uint32_t cluster);
static int fat_get_next_cluster_impl(uint32_t cluster, uint32_t* next);
static int fat_set_next_cluster_impl(uint32_t cluster, uint32_t next);

/* ================================================================ */
/* File System Initialization                                         */
/* ================================================================ */

int fs_init(void) {
    if (fs_initialized) {
        return FS_SUCCESS;
    }
    
    /* Initialize all file systems */
    for (int i = 0; i < 26; i++) {
        file_systems[i].disk = NULL;
        file_systems[i].initialized = 0;
        file_systems[i].open_file_count = 0;
    }
    
    /* Initialize virtual disks */
    for (int i = 0; i < MAX_VIRTUAL_DISKS; i++) {
        virtual_disks[i].mounted = 0;
    }
    
    /* Create default C: drive */
    const char* default_disk = "ksdos_c.img";
    if (vd_create_disk(default_disk, 2 * 1024 * 1024) == FS_SUCCESS) {  /* 2MB */
        fs_mount_disk(default_disk, 'C');
        vd_format_fat16(&virtual_disks[2], "KSDOS");
    }
    
    /* Create A: drive (floppy) */
    const char* floppy_disk = "ksdos_a.img";
    if (vd_create_disk(floppy_disk, 1440 * 1024) == FS_SUCCESS) {  /* 1.44MB */
        fs_mount_disk(floppy_disk, 'A');
        vd_format_fat12(&virtual_disks[0], "BOOTDISK");
    }
    
    fs_initialized = 1;
    return FS_SUCCESS;
}

int fs_shutdown(void) {
    if (!fs_initialized) {
        return FS_SUCCESS;
    }
    
    /* Close all open files */
    for (int i = 0; i < 26; i++) {
        if (file_systems[i].initialized) {
            for (int j = 0; j < MAX_OPEN_FILES; j++) {
                if (file_systems[i].open_files[j].used) {
                    fs_close_file(j);
                }
            }
        }
    }
    
    /* Unmount all disks */
    for (int i = 0; i < 26; i++) {
        if (file_systems[i].disk && file_systems[i].disk->mounted) {
            fs_unmount_disk('A' + i);
        }
    }
    
    fs_initialized = 0;
    return FS_SUCCESS;
}

/* ================================================================ */
/* Virtual Disk Management                                            */
/* ================================================================ */

int vd_create_disk(const char* filename, uint32_t size) {
    if (virtual_disk_count >= MAX_VIRTUAL_DISKS) {
        return FS_ERROR_TOO_MANY_OPEN_FILES;
    }
    
    /* Find free slot */
    int slot = -1;
    for (int i = 0; i < MAX_VIRTUAL_DISKS; i++) {
        if (!virtual_disks[i].mounted) {
            slot = i;
            break;
        }
    }
    
    if (slot == -1) {
        return FS_ERROR_DISK_FULL;
    }
    
    virtual_disk_t* disk = &virtual_disks[slot];
    
    /* Initialize disk structure */
    strcpy(disk->filename, filename);
    disk->size = size;
    disk->sector_count = size / SECTOR_SIZE;
    disk->bytes_per_sector = SECTOR_SIZE;
    disk->sectors_per_cluster = 4;  /* 2KB clusters */
    disk->mounted = 0;
    
    /* Allocate memory for disk image */
    disk->data = malloc(size);
    if (!disk->data) {
        return FS_ERROR_NOT_ENOUGH_MEMORY;
    }
    
    /* Initialize disk with zeros */
    memset(disk->data, 0, size);
    
    virtual_disk_count++;
    return FS_SUCCESS;
}

int vd_delete_disk(const char* filename) {
    /* Find disk */
    for (int i = 0; i < MAX_VIRTUAL_DISKS; i++) {
        if (virtual_disks[i].mounted && 
            strcmp(virtual_disks[i].filename, filename) == 0) {
            if (virtual_disks[i].mounted) {
                return FS_ERROR_ACCESS_DENIED;
            }
            free(virtual_disks[i].data);
            virtual_disks[i].mounted = 0;
            virtual_disk_count--;
            return FS_SUCCESS;
        }
    }
    
    return FS_ERROR_FILE_NOT_FOUND;
}

int vd_open_disk(const char* filename, virtual_disk_t* disk) {
    /* Find disk */
    for (int i = 0; i < MAX_VIRTUAL_DISKS; i++) {
        if (virtual_disks[i].mounted && 
            strcmp(virtual_disks[i].filename, filename) == 0) {
            *disk = virtual_disks[i];
            return FS_SUCCESS;
        }
    }
    
    return FS_ERROR_FILE_NOT_FOUND;
}

int vd_close_disk(virtual_disk_t* disk) {
    /* Unmount disk */
    disk->mounted = 0;
    return FS_SUCCESS;
}

int vd_read_sector(virtual_disk_t* disk, uint32_t sector, uint8_t* buffer) {
    if (!disk->mounted || sector >= disk->sector_count) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    uint32_t offset = sector * disk->bytes_per_sector;
    memcpy(buffer, disk->data + offset, disk->bytes_per_sector);
    
    return FS_SUCCESS;
}

int vd_write_sector(virtual_disk_t* disk, uint32_t sector, const uint8_t* buffer) {
    if (!disk->mounted || sector >= disk->sector_count) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    uint32_t offset = sector * disk->bytes_per_sector;
    memcpy(disk->data + offset, buffer, disk->bytes_per_sector);
    
    return FS_SUCCESS;
}

/* ================================================================ */
/* FAT Formatting Functions                                           */
/* ================================================================ */

int vd_format_fat12(virtual_disk_t* disk, const char* label) {
    if (!disk->mounted) {
        return FS_ERROR_NOT_READY;
    }
    
    disk->fs_type = FS_TYPE_FAT12;
    disk->sectors_per_cluster = 1;
    disk->fat_start = 1;
    disk->fat_size = 9;  /* 9 sectors for FAT12 */
    disk->data_start = disk->fat_start + (2 * disk->fat_size);
    disk->root_start = disk->data_start;
    disk->root_size = 14;  /* 14 sectors for root */
    disk->cluster_count = (disk->sector_count - disk->data_start) / disk->sectors_per_cluster;
    
    /* Generate serial number */
    srand(time(NULL));
    disk->serial_number = rand();
    
    /* Copy volume label */
    strncpy(disk->label, label, 11);
    disk->label[11] = '\0';
    
    /* Create boot sector */
    fat_boot_sector_t boot;
    memset(&boot, 0, sizeof(boot));
    
    boot.jump_boot[0] = 0xEB;
    boot.jump_boot[1] = 0x3C;
    boot.jump_boot[2] = 0x90;
    strcpy(boot.oem_name, "KSDOS1.0");
    boot.bytes_per_sector = disk->bytes_per_sector;
    boot.sectors_per_cluster = disk->sectors_per_cluster;
    boot.reserved_sectors = disk->fat_start;
    boot.num_fats = 2;
    boot.root_entries = 224;
    boot.total_sectors_16 = disk->sector_count;
    boot.media_type = 0xF8;
    boot.fat_size_16 = disk->fat_size;
    boot.sectors_per_track = 18;
    boot.num_heads = 2;
    boot.hidden_sectors = 0;
    boot.total_sectors_32 = 0;
    
    /* Write boot sector */
    vd_write_sector(disk, 0, (uint8_t*)&boot);
    
    /* Initialize FAT */
    uint8_t fat_sector[SECTOR_SIZE];
    memset(fat_sector, 0, SECTOR_SIZE);
    
    /* FAT12 signature */
    fat_sector[0] = 0xF0;
    fat_sector[1] = 0xFF;
    fat_sector[2] = 0xFF;
    
    /* Write FATs */
    for (int i = 0; i < disk->fat_size; i++) {
        vd_write_sector(disk, disk->fat_start + i, fat_sector);
        vd_write_sector(disk, disk->fat_start + disk->fat_size + i, fat_sector);
    }
    
    /* Initialize root directory */
    uint8_t root_dir[SECTOR_SIZE];
    memset(root_dir, 0, SECTOR_SIZE);
    
    /* Create volume label entry */
    fat_dir_entry_t* volume_entry = (fat_dir_entry_t*)root_dir;
    memset(volume_entry->name, ' ', 11);
    strncpy(volume_entry->name, disk->label, 11);
    volume_entry->attributes = ATTR_VOLUME_ID;
    volume_entry->creation_date = 0x3A20;  /* January 1, 2026 */
    volume_entry->creation_time = 0x0000;
    volume_entry->write_date = 0x3A20;
    volume_entry->write_time = 0x0000;
    volume_entry->last_access_date = 0x3A20;
    volume_entry->file_size = 0;
    
    /* Write root directory */
    for (int i = 0; i < disk->root_size; i++) {
        vd_write_sector(disk, disk->root_start + i, root_dir);
    }
    
    return FS_SUCCESS;
}

int vd_format_fat16(virtual_disk_t* disk, const char* label) {
    if (!disk->mounted) {
        return FS_ERROR_NOT_READY;
    }
    
    disk->fs_type = FS_TYPE_FAT16;
    disk->sectors_per_cluster = 4;  /* 2KB clusters */
    disk->fat_start = 1;
    disk->fat_size = (disk->sector_count / disk->sectors_per_cluster + 1) * 2 / SECTOR_SIZE;
    disk->data_start = disk->fat_start + (2 * disk->fat_size);
    disk->root_start = disk->data_start;
    disk->root_size = 32;  /* 32 sectors for root */
    disk->cluster_count = (disk->sector_count - disk->data_start) / disk->sectors_per_cluster;
    
    /* Generate serial number */
    srand(time(NULL));
    disk->serial_number = rand();
    
    /* Copy volume label */
    strncpy(disk->label, label, 11);
    disk->label[11] = '\0';
    
    /* Create boot sector */
    fat_boot_sector_t boot;
    memset(&boot, 0, sizeof(boot));
    
    boot.jump_boot[0] = 0xEB;
    boot.jump_boot[1] = 0x3C;
    boot.jump_boot[2] = 0x90;
    strcpy(boot.oem_name, "KSDOS1.0");
    boot.bytes_per_sector = disk->bytes_per_sector;
    boot.sectors_per_cluster = disk->sectors_per_cluster;
    boot.reserved_sectors = disk->fat_start;
    boot.num_fats = 2;
    boot.root_entries = 512;
    boot.total_sectors_16 = disk->sector_count;
    boot.media_type = 0xF8;
    boot.fat_size_16 = disk->fat_size;
    boot.sectors_per_track = 63;
    boot.num_heads = 16;
    boot.hidden_sectors = 0;
    boot.total_sectors_32 = 0;
    
    /* Write boot sector */
    vd_write_sector(disk, 0, (uint8_t*)&boot);
    
    /* Initialize FAT */
    uint8_t fat_sector[SECTOR_SIZE];
    memset(fat_sector, 0, SECTOR_SIZE);
    
    /* FAT16 signature */
    fat_sector[0] = 0xF8;
    fat_sector[1] = 0xFF;
    fat_sector[2] = 0xFF;
    
    /* Write FATs */
    for (int i = 0; i < disk->fat_size; i++) {
        vd_write_sector(disk, disk->fat_start + i, fat_sector);
        vd_write_sector(disk, disk->fat_start + disk->fat_size + i, fat_sector);
    }
    
    /* Initialize root directory */
    uint8_t root_dir[SECTOR_SIZE];
    memset(root_dir, 0, SECTOR_SIZE);
    
    /* Create volume label entry */
    fat_dir_entry_t* volume_entry = (fat_dir_entry_t*)root_dir;
    memset(volume_entry->name, ' ', 11);
    strncpy(volume_entry->name, disk->label, 11);
    volume_entry->attributes = ATTR_VOLUME_ID;
    volume_entry->creation_date = 0x3A20;  /* January 1, 2026 */
    volume_entry->creation_time = 0x0000;
    volume_entry->write_date = 0x3A20;
    volume_entry->write_time = 0x0000;
    volume_entry->last_access_date = 0x3A20;
    volume_entry->file_size = 0;
    
    /* Write root directory */
    for (int i = 0; i < disk->root_size; i++) {
        vd_write_sector(disk, disk->root_start + i, root_dir);
    }
    
    return FS_SUCCESS;
}

int vd_format_fat32(virtual_disk_t* disk, const char* label) {
    /* FAT32 implementation would go here */
    return FS_ERROR_UNSUPPORTED_OPERATION;
}

/* ================================================================ */
/* File System Mounting                                                */
/* ================================================================ */

int fs_mount_disk(const char* filename, char drive_letter) {
    if (!fs_initialized) {
        return FS_ERROR_NOT_READY;
    }
    
    int drive_index = drive_letter - 'A';
    if (drive_index < 0 || drive_index >= 26) {
        return FS_ERROR_INVALID_DRIVE;
    }
    
    /* Find virtual disk */
    virtual_disk_t* disk = NULL;
    for (int i = 0; i < MAX_VIRTUAL_DISKS; i++) {
        if (virtual_disks[i].mounted && 
            strcmp(virtual_disks[i].filename, filename) == 0) {
            disk = &virtual_disks[i];
            break;
        }
    }
    
    if (!disk) {
        return FS_ERROR_FILE_NOT_FOUND;
    }
    
    /* Initialize file system */
    file_system_t* fs = &file_systems[drive_index];
    fs->disk = disk;
    fs->type = disk->fs_type;
    fs->root_cluster = 2;  /* Root starts at cluster 2 */
    fs->current_dir = fs->root_cluster;
    sprintf(fs->current_path, "%c:\\", drive_letter);
    fs->open_file_count = 0;
    
    /* Initialize file operations */
    fs->ops.read_sector = fat_read_sector_impl;
    fs->ops.write_sector = fat_write_sector_impl;
    fs->ops.read_cluster = fat_read_cluster_impl;
    fs->ops.write_cluster = fat_write_cluster_impl;
    fs->ops.allocate_cluster = fat_allocate_cluster_impl;
    fs->ops.free_cluster = fat_free_cluster_impl;
    fs->ops.get_next_cluster = fat_get_next_cluster_impl;
    fs->ops.set_next_cluster = fat_set_next_cluster_impl;
    
    /* Read FAT */
    if (fat_init(fs) != FS_SUCCESS) {
        return FS_ERROR_FAT_CORRUPT;
    }
    
    /* Initialize open file handles */
    for (int i = 0; i < MAX_OPEN_FILES; i++) {
        fs->open_files[i].used = 0;
    }
    
    fs->initialized = 1;
    disk->mounted = 1;
    
    return FS_SUCCESS;
}

int fs_unmount_disk(char drive_letter) {
    int drive_index = drive_letter - 'A';
    if (drive_index < 0 || drive_index >= 26) {
        return FS_ERROR_INVALID_DRIVE;
    }
    
    file_system_t* fs = &file_systems[drive_index];
    if (!fs->initialized) {
        return FS_ERROR_INVALID_DRIVE;
    }
    
    /* Close all open files */
    for (int i = 0; i < MAX_OPEN_FILES; i++) {
        if (fs->open_files[i].used) {
            fs_close_file(i);
        }
    }
    
    /* Write FAT */
    fat_write_fat(fs);
    
    /* Unmount */
    if (fs->disk) {
        fs->disk->mounted = 0;
    }
    fs->initialized = 0;
    
    return FS_SUCCESS;
}

/* ================================================================ */
/* File Operations                                                    */
/* ================================================================ */

int fs_create_file(const char* path) {
    if (!fs_initialized) {
        return FS_ERROR_NOT_READY;
    }
    
    /* Parse path */
    char drive, directory[MAX_PATH_LENGTH], filename[MAX_FILENAME_LENGTH];
    if (fs_parse_path(path, &drive, directory, filename) != FS_SUCCESS) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    int drive_index = drive - 'A';
    file_system_t* fs = &file_systems[drive_index];
    if (!fs->initialized) {
        return FS_ERROR_INVALID_DRIVE;
    }
    
    /* Check if file already exists */
    fat_dir_entry_t entry;
    if (fat_find_directory_entry(fs, filename, &entry) == FS_SUCCESS) {
        return FS_ERROR_ALREADY_EXISTS;
    }
    
    /* Create directory entry */
    uint32_t cluster;
    int result = fat_create_directory_entry(fs, filename, ATTR_ARCHIVE, &cluster);
    if (result != FS_SUCCESS) {
        return result;
    }
    
    return FS_SUCCESS;
}

int fs_delete_file(const char* path) {
    if (!fs_initialized) {
        return FS_ERROR_NOT_READY;
    }
    
    /* Parse path */
    char drive, directory[MAX_PATH_LENGTH], filename[MAX_FILENAME_LENGTH];
    if (fs_parse_path(path, &drive, directory, filename) != FS_SUCCESS) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    int drive_index = drive - 'A';
    file_system_t* fs = &file_systems[drive_index];
    if (!fs->initialized) {
        return FS_ERROR_INVALID_DRIVE;
    }
    
    /* Find directory entry */
    fat_dir_entry_t entry;
    if (fat_find_directory_entry(fs, filename, &entry) != FS_SUCCESS) {
        return FS_ERROR_FILE_NOT_FOUND;
    }
    
    /* Free cluster chain */
    uint32_t first_cluster = (entry.first_cluster_hi << 16) | entry.first_cluster_lo;
    fat_free_cluster_chain(fs, first_cluster);
    
    /* Delete directory entry */
    fat_delete_directory_entry(fs, filename);
    
    return FS_SUCCESS;
}

int fs_open_file(const char* path, const char* mode, int* handle) {
    if (!fs_initialized) {
        return FS_ERROR_NOT_READY;
    }
    
    /* Parse path */
    char drive, directory[MAX_PATH_LENGTH], filename[MAX_FILENAME_LENGTH];
    if (fs_parse_path(path, &drive, directory, filename) != FS_SUCCESS) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    int drive_index = drive - 'A';
    file_system_t* fs = &file_systems[drive_index];
    if (!fs->initialized) {
        return FS_ERROR_INVALID_DRIVE;
    }
    
    /* Find free file handle */
    int handle_index = -1;
    for (int i = 0; i < MAX_OPEN_FILES; i++) {
        if (!fs->open_files[i].used) {
            handle_index = i;
            break;
        }
    }
    
    if (handle_index == -1) {
        return FS_ERROR_TOO_MANY_OPEN_FILES;
    }
    
    /* Find directory entry */
    fat_dir_entry_t entry;
    if (fat_find_directory_entry(fs, filename, &entry) != FS_SUCCESS) {
        return FS_ERROR_FILE_NOT_FOUND;
    }
    
    /* Initialize file handle */
    file_handle_t* file = &fs->open_files[handle_index];
    file->used = 1;
    strcpy(file->filename, path);
    file->size = entry.file_size;
    file->position = 0;
    file->first_cluster = (entry.first_cluster_hi << 16) | entry.first_cluster_lo;
    file->current_cluster = file->first_cluster;
    file->mode = mode[0];  /* First character of mode */
    file->attributes = entry.attributes;
    
    /* Read time stamps */
    file->creation_time.year = 1980 + (entry.creation_date >> 9);
    file->creation_time.month = (entry.creation_date >> 5) & 0x0F;
    file->creation_time.day = entry.creation_date & 0x1F;
    file->creation_time.hour = entry.creation_time >> 11;
    file->creation_time.minute = (entry.creation_time >> 5) & 0x3F;
    file->creation_time.second = (entry.creation_time & 0x1F) * 2;
    
    file->modification_time.year = 1980 + (entry.write_date >> 9);
    file->modification_time.month = (entry.write_date >> 5) & 0x0F;
    file->modification_time.day = entry.write_date & 0x1F;
    file->modification_time.hour = entry.write_time >> 11;
    file->modification_time.minute = (entry.write_time >> 5) & 0x3F;
    file->modification_time.second = (entry.write_time & 0x1F) * 2;
    
    file->access_time.year = 1980 + (entry.last_access_date >> 9);
    file->access_time.month = (entry.last_access_date >> 5) & 0x0F;
    file->access_time.day = entry.last_access_date & 0x1F;
    file->access_time.hour = 12;
    file->access_time.minute = 0;
    file->access_time.second = 0;
    
    /* Allocate buffer for file data */
    file->data = malloc(file->size + 1);
    if (!file->data) {
        file->used = 0;
        return FS_ERROR_NOT_ENOUGH_MEMORY;
    }
    
    /* Read file data */
    uint32_t cluster = file->first_cluster;
    uint32_t bytes_read = 0;
    uint8_t cluster_data[CLUSTER_SIZE_MAX];
    
    while (cluster != FAT_END_OF_CHAIN && bytes_read < file->size) {
        if (fs->ops.read_cluster(cluster, cluster_data) != FS_SUCCESS) {
            free(file->data);
            file->used = 0;
            return FS_ERROR_CLUSTER_NOT_FOUND;
        }
        
        uint32_t bytes_to_copy = file->size - bytes_read;
        if (bytes_to_copy > fs->disk->sectors_per_cluster * SECTOR_SIZE) {
            bytes_to_copy = fs->disk->sectors_per_cluster * SECTOR_SIZE;
        }
        
        memcpy(file->data + bytes_read, cluster_data, bytes_to_copy);
        bytes_read += bytes_to_copy;
        
        /* Get next cluster */
        if (fs->ops.get_next_cluster(cluster, &cluster) != FS_SUCCESS) {
            break;
        }
    }
    
    file->data[file->size] = '\0';  /* Null terminate for text files */
    
    fs->open_file_count++;
    *handle = handle_index;
    
    return FS_SUCCESS;
}

int fs_close_file(int handle) {
    if (!fs_initialized || handle < 0 || handle >= MAX_OPEN_FILES) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    /* Find which file system this handle belongs to */
    file_system_t* fs = NULL;
    for (int i = 0; i < 26; i++) {
        if (file_systems[i].initialized && 
            file_systems[i].open_files[handle].used) {
            fs = &file_systems[i];
            break;
        }
    }
    
    if (!fs) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    file_handle_t* file = &fs->open_files[handle];
    if (!file->used) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    /* Write back data if file was modified */
    if (file->mode == 'w' || file->mode == 'a' || file->mode == '+') {
        /* Write file data back to clusters */
        uint32_t cluster = file->first_cluster;
        uint32_t bytes_written = 0;
        uint8_t cluster_data[CLUSTER_SIZE_MAX];
        
        while (cluster != FAT_END_OF_CHAIN && bytes_written < file->size) {
            uint32_t bytes_to_copy = file->size - bytes_written;
            if (bytes_to_copy > fs->disk->sectors_per_cluster * SECTOR_SIZE) {
                bytes_to_copy = fs->disk->sectors_per_cluster * SECTOR_SIZE;
            }
            
            memset(cluster_data, 0, sizeof(cluster_data));
            memcpy(cluster_data, file->data + bytes_written, bytes_to_copy);
            
            if (fs->ops.write_cluster(cluster, cluster_data) != FS_SUCCESS) {
                break;
            }
            
            bytes_written += bytes_to_copy;
            
            /* Get next cluster */
            if (fs->ops.get_next_cluster(cluster, &cluster) != FS_SUCCESS) {
                break;
            }
        }
    }
    
    /* Free file data */
    free(file->data);
    file->used = 0;
    fs->open_file_count--;
    
    return FS_SUCCESS;
}

int fs_read_file(int handle, void* buffer, uint32_t size, uint32_t* bytes_read) {
    if (!fs_initialized || handle < 0 || handle >= MAX_OPEN_FILES) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    /* Find file system */
    file_system_t* fs = NULL;
    for (int i = 0; i < 26; i++) {
        if (file_systems[i].initialized && 
            file_systems[i].open_files[handle].used) {
            fs = &file_systems[i];
            break;
        }
    }
    
    if (!fs) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    file_handle_t* file = &fs->open_files[handle];
    if (!file->used || file->mode == 'w') {
        return FS_ERROR_ACCESS_DENIED;
    }
    
    /* Calculate bytes to read */
    uint32_t bytes_to_read = size;
    if (file->position + bytes_to_read > file->size) {
        bytes_to_read = file->size - file->position;
    }
    
    /* Copy data */
    memcpy(buffer, file->data + file->position, bytes_to_read);
    file->position += bytes_to_read;
    
    if (bytes_read) {
        *bytes_read = bytes_to_read;
    }
    
    return FS_SUCCESS;
}

int fs_write_file(int handle, const void* buffer, uint32_t size, uint32_t* bytes_written) {
    if (!fs_initialized || handle < 0 || handle >= MAX_OPEN_FILES) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    /* Find file system */
    file_system_t* fs = NULL;
    for (int i = 0; i < 26; i++) {
        if (file_systems[i].initialized && 
            file_systems[i].open_files[handle].used) {
            fs = &file_systems[i];
            break;
        }
    }
    
    if (!fs) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    file_handle_t* file = &fs->open_files[handle];
    if (!file->used || file->mode == 'r') {
        return FS_ERROR_ACCESS_DENIED;
    }
    
    /* Resize file data if needed */
    if (file->position + size > file->size) {
        file->data = realloc(file->data, file->position + size + 1);
        if (!file->data) {
            return FS_ERROR_NOT_ENOUGH_MEMORY;
        }
        file->size = file->position + size;
    }
    
    /* Copy data */
    memcpy(file->data + file->position, buffer, size);
    file->position += size;
    
    if (bytes_written) {
        *bytes_written = size;
    }
    
    return FS_SUCCESS;
}

/* ================================================================ */
/* Directory Operations                                               */
/* ================================================================ */

int fs_create_directory(const char* path) {
    if (!fs_initialized) {
        return FS_ERROR_NOT_READY;
    }
    
    /* Parse path */
    char drive, directory[MAX_PATH_LENGTH], filename[MAX_FILENAME_LENGTH];
    if (fs_parse_path(path, &drive, directory, filename) != FS_SUCCESS) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    int drive_index = drive - 'A';
    file_system_t* fs = &file_systems[drive_index];
    if (!fs->initialized) {
        return FS_ERROR_INVALID_DRIVE;
    }
    
    /* Create directory entry */
    uint32_t cluster;
    int result = fat_create_directory_entry(fs, filename, ATTR_DIRECTORY, &cluster);
    if (result != FS_SUCCESS) {
        return result;
    }
    
    /* Initialize directory with . and .. entries */
    uint8_t cluster_data[CLUSTER_SIZE_MAX];
    memset(cluster_data, 0, sizeof(cluster_data));
    
    /* Create . entry */
    fat_dir_entry_t* dot_entry = (fat_dir_entry_t*)cluster_data;
    memset(dot_entry->name, ' ', 11);
    strcpy(dot_entry->name, ".          ");
    dot_entry->attributes = ATTR_DIRECTORY;
    dot_entry->first_cluster_lo = cluster & 0xFFFF;
    dot_entry->first_cluster_hi = (cluster >> 16) & 0xFFFF;
    
    /* Create .. entry */
    fat_dir_entry_t* dotdot_entry = (fat_dir_entry_t*)(cluster_data + 32);
    memset(dotdot_entry->name, ' ', 11);
    strcpy(dotdot_entry->name, "..         ");
    dotdot_entry->attributes = ATTR_DIRECTORY;
    dotdot_entry->first_cluster_lo = fs->current_dir & 0xFFFF;
    dotdot_entry->first_cluster_hi = (fs->current_dir >> 16) & 0xFFFF;
    
    /* Write directory cluster */
    fs->ops.write_cluster(cluster, cluster_data);
    
    return FS_SUCCESS;
}

int fs_list_directory(const char* path, directory_t* dir_info) {
    if (!fs_initialized) {
        return FS_ERROR_NOT_READY;
    }
    
    /* Parse path */
    char drive, directory[MAX_PATH_LENGTH], filename[MAX_FILENAME_LENGTH];
    if (fs_parse_path(path, &drive, directory, filename) != FS_SUCCESS) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    int drive_index = drive - 'A';
    file_system_t* fs = &file_systems[drive_index];
    if (!fs->initialized) {
        return FS_ERROR_INVALID_DRIVE;
    }
    
    /* Read directory */
    return fat_read_directory(fs, fs->current_dir, dir_info);
}

/* ================================================================ */
/* Utility Functions                                                  */
/* ================================================================ */

int fs_parse_path(const char* path, char* drive, char* directory, char* filename) {
    if (!path || strlen(path) == 0) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    /* Extract drive letter */
    if (strlen(path) >= 2 && path[1] == ':') {
        *drive = toupper(path[0]);
        path += 2;
    } else {
        *drive = current_drive;
    }
    
    /* Skip leading backslashes */
    while (*path == '\\') {
        path++;
    }
    
    /* Find last backslash to separate directory from filename */
    const char* last_backslash = strrchr(path, '\\');
    if (last_backslash) {
        /* Copy directory */
        size_t dir_len = last_backslash - path;
        strncpy(directory, path, dir_len);
        directory[dir_len] = '\0';
        
        /* Copy filename */
        strcpy(filename, last_backslash + 1);
    } else {
        /* No directory, just filename */
        strcpy(directory, "");
        strcpy(filename, path);
    }
    
    return FS_SUCCESS;
}

int fs_validate_filename(const char* filename) {
    if (!filename || strlen(filename) == 0 || strlen(filename) > MAX_FILENAME_LENGTH) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    /* Check for invalid characters */
    const char* invalid_chars = "<>:\"|?*";
    for (const char* p = filename; *p; p++) {
        if (*p < 32 || strchr(invalid_chars, *p)) {
            return FS_ERROR_INVALID_PARAMETER;
        }
    }
    
    return FS_SUCCESS;
}

char* fs_get_current_directory(void) {
    return current_directory;
}

int fs_set_current_directory(const char* path) {
    if (!path) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    strcpy(current_directory, path);
    return FS_SUCCESS;
}

/* ================================================================ */
/* FAT Implementation Functions                                        */
/* ================================================================ */

int fat_init(file_system_t* fs) {
    if (!fs || !fs->disk) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    /* Allocate FAT buffer */
    fs->fat_size = fs->disk->fat_size * SECTOR_SIZE;
    fs->fat = malloc(fs->fat_size);
    if (!fs->fat) {
        return FS_ERROR_NOT_ENOUGH_MEMORY;
    }
    
    /* Read FAT */
    return fat_read_fat(fs);
}

int fat_read_fat(file_system_t* fs) {
    if (!fs || !fs->fat) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    /* Read first FAT copy */
    for (uint32_t i = 0; i < fs->disk->fat_size; i++) {
        uint8_t sector[SECTOR_SIZE];
        if (fs->ops.read_sector(fs->disk->fat_start + i, sector) != FS_SUCCESS) {
            return FS_ERROR_SECTOR_NOT_FOUND;
        }
        memcpy(fs->fat + i * SECTOR_SIZE, sector, SECTOR_SIZE);
    }
    
    return FS_SUCCESS;
}

int fat_write_fat(file_system_t* fs) {
    if (!fs || !fs->fat) {
        return FS_ERROR_INVALID_PARAMETER;
    }
    
    /* Write both FAT copies */
    for (int copy = 0; copy < 2; copy++) {
        for (uint32_t i = 0; i < fs->disk->fat_size; i++) {
            uint8_t sector[SECTOR_SIZE];
            memcpy(sector, fs->fat + i * SECTOR_SIZE, SECTOR_SIZE);
            if (fs->ops.write_sector(fs->disk->fat_start + copy * fs->disk->fat_size + i, sector) != FS_SUCCESS) {
                return FS_ERROR_SECTOR_NOT_FOUND;
            }
        }
    }
    
    return FS_SUCCESS;
}

/* FAT operation implementations */
static int fat_read_sector_impl(uint32_t sector, uint8_t* buffer) {
    /* This would be implemented based on the current file system */
    return FS_SUCCESS;
}

static int fat_write_sector_impl(uint32_t sector, const uint8_t* buffer) {
    /* This would be implemented based on the current file system */
    return FS_SUCCESS;
}

static int fat_read_cluster_impl(uint32_t cluster, uint8_t* buffer) {
    /* This would be implemented based on the current file system */
    return FS_SUCCESS;
}

static int fat_write_cluster_impl(uint32_t cluster, const uint8_t* buffer) {
    /* This would be implemented based on the current file system */
    return FS_SUCCESS;
}

static int fat_allocate_cluster_impl(void) {
    /* This would be implemented based on the current file system */
    return FS_SUCCESS;
}

static int fat_free_cluster_impl(uint32_t cluster) {
    /* This would be implemented based on the current file system */
    return FS_SUCCESS;
}

static int fat_get_next_cluster_impl(uint32_t cluster, uint32_t* next) {
    /* This would be implemented based on the current file system */
    return FS_SUCCESS;
}

static int fat_set_next_cluster_impl(uint32_t cluster, uint32_t next) {
    /* This would be implemented based on the current file system */
    return FS_SUCCESS;
}

/* Stub implementations for remaining FAT functions */
int fat_get_next_cluster(file_system_t* fs, uint32_t cluster, uint32_t* next) { return FS_SUCCESS; }
int fat_set_next_cluster(file_system_t* fs, uint32_t cluster, uint32_t next) { return FS_SUCCESS; }
int fat_allocate_cluster(file_system_t* fs, uint32_t* cluster) { return FS_SUCCESS; }
int fat_free_cluster_chain(file_system_t* fs, uint32_t start_cluster) { return FS_SUCCESS; }
int fat_read_directory(file_system_t* fs, uint32_t cluster, directory_t* dir) { return FS_SUCCESS; }
int fat_write_directory(file_system_t* fs, const directory_t* dir) { return FS_SUCCESS; }
int fat_create_directory_entry(file_system_t* fs, const char* name, uint8_t attributes, uint32_t* cluster) { return FS_SUCCESS; }
int fat_delete_directory_entry(file_system_t* fs, const char* name) { return FS_SUCCESS; }
int fat_find_directory_entry(file_system_t* fs, const char* name, fat_dir_entry_t* entry) { return FS_SUCCESS; }

/* Additional stub implementations */
int fs_seek_file(int handle, int32_t offset, int whence) { return FS_SUCCESS; }
int fs_tell_file(int handle, uint32_t* position) { return FS_SUCCESS; }
int fs_eof_file(int handle) { return 0; }
int fs_flush_file(int handle) { return FS_SUCCESS; }
int fs_delete_directory(const char* path) { return FS_SUCCESS; }
int fs_change_directory(const char* path) { return FS_SUCCESS; }
int fs_find_first_file(const char* path, const char* pattern, file_handle_t* handle) { return FS_SUCCESS; }
int fs_find_next_file(file_handle_t* handle, char* filename) { return FS_SUCCESS; }
int fs_find_close(file_handle_t* handle) { return FS_SUCCESS; }
int fs_get_file_info(const char* path, fs_time_t* creation, fs_time_t* modification, fs_time_t* access, uint32_t* size, uint8_t* attributes) { return FS_SUCCESS; }
int fs_set_file_info(const char* path, const fs_time_t* creation, const fs_time_t* modification, const fs_time_t* access, uint8_t* attributes) { return FS_SUCCESS; }
int fs_copy_file(const char* src_path, const char* dst_path) { return FS_SUCCESS; }
int fs_move_file(const char* src_path, const char* dst_path) { return FS_SUCCESS; }
int fs_get_disk_info(char drive, uint32_t* total_space, uint32_t* free_space, uint32_t* cluster_size, char* label) { return FS_SUCCESS; }
int fs_defragment_disk(char drive) { return FS_SUCCESS; }
int fs_check_disk(char drive) { return FS_SUCCESS; }
int fs_cleanup_disk(char drive) { return FS_SUCCESS; }
