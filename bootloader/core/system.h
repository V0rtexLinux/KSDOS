/* ================================================================
   KSDOS Real System Management
   Complete system management with process control, memory management, and hardware monitoring
   ================================================================ */

#ifndef KSDOS_SYSTEM_H
#define KSDOS_SYSTEM_H

#include <stdint.h>
#include <time.h>

/* System Information */
#define KSDOS_VERSION_MAJOR    1
#define KSDOS_VERSION_MINOR    0
#define KSDOS_VERSION_PATCH    0
#define KSDOS_BUILD_NUMBER     20260318

/* Process States */
#define PROCESS_STATE_READY     0
#define PROCESS_STATE_RUNNING   1
#define PROCESS_STATE_BLOCKED   2
#define PROCESS_STATE_TERMINATED 3
#define PROCESS_STATE_ZOMBIE    4

/* Process Types */
#define PROCESS_TYPE_SYSTEM     0
#define PROCESS_TYPE_USER       1
#define PROCESS_TYPE_DRIVER     2
#define PROCESS_TYPE_SERVICE    3

/* Memory Types */
#define MEMORY_TYPE_RAM         0
#define MEMORY_TYPE_ROM         1
#define MEMORY_TYPE_VIDEO       2
#define MEMORY_TYPE_CACHE       3
#define MEMORY_TYPE_VIRTUAL     4

/* CPU States */
#define CPU_STATE_IDLE          0
#define CPU_STATE_NORMAL        1
#define CPU_STATE_BUSY          2
#define CPU_STATE_OVERLOAD      3

/* Device Types */
#define DEVICE_TYPE_DISK        0
#define DEVICE_TYPE_KEYBOARD    1
#define DEVICE_TYPE_MOUSE       2
#define DEVICE_TYPE_DISPLAY     3
#define DEVICE_TYPE_NETWORK     4
#define DEVICE_TYPE_AUDIO       5
#define DEVICE_TYPE_PRINTER     6
#define DEVICE_TYPE_SERIAL      7
#define DEVICE_TYPE_PARALLEL    8
#define DEVICE_TYPE_USB         9

/* Power States */
#define POWER_STATE_ON          0
#define POWER_STATE_OFF         1
#define POWER_STATE_SLEEP        2
#define POWER_STATE_HIBERNATE    3
#define POWER_STATE_SUSPEND      4

/* System Events */
#define EVENT_TYPE_PROCESS_CREATE    0
#define EVENT_TYPE_PROCESS_TERMINATE 1
#define EVENT_TYPE_MEMORY_ALLOCATE   2
#define EVENT_TYPE_MEMORY_FREE       3
#define EVENT_TYPE_DEVICE_CONNECT   4
#define EVENT_TYPE_DEVICE_DISCONNECT 5
#define EVENT_TYPE_SYSTEM_ERROR     6
#define EVENT_TYPE_USER_LOGON       7
#define EVENT_TYPE_USER_LOGOFF      8

/* Process Structure */
typedef struct {
    uint32_t pid;                    /* Process ID */
    uint32_t ppid;                   /* Parent Process ID */
    char name[256];                  /* Process name */
    char path[512];                  /* Executable path */
    uint8_t state;                   /* Process state */
    uint8_t type;                    /* Process type */
    uint8_t priority;                /* Priority (0-31) */
    uint32_t memory_usage;           /* Memory usage in KB */
    uint32_t cpu_time;               /* CPU time in milliseconds */
    uint32_t start_time;             /* Start time */
    uint32_t end_time;               /* End time */
    uint32_t thread_count;           /* Number of threads */
    uint32_t handle_count;           /* Number of open handles */
    uint32_t page_faults;            /* Number of page faults */
    uint32_t io_read_bytes;          /* Bytes read */
    uint32_t io_write_bytes;         /* Bytes written */
    uint32_t user_id;                /* User ID */
    uint32_t group_id;               /* Group ID */
    int exit_code;                   /* Exit code */
    void* stack_pointer;             /* Stack pointer */
    void* heap_pointer;              /* Heap pointer */
} process_info_t;

/* Memory Region Structure */
typedef struct {
    uint32_t base_address;           /* Base address */
    uint32_t size;                   /* Size in bytes */
    uint8_t type;                    /* Memory type */
    uint8_t protection;              /* Protection flags */
    uint32_t owner_pid;              /* Owner process ID */
    char description[256];           /* Description */
} memory_region_t;

/* Device Structure */
typedef struct {
    uint8_t type;                    /* Device type */
    uint8_t state;                   /* Device state */
    char name[64];                   /* Device name */
    char description[256];           /* Description */
    uint32_t driver_version;         /* Driver version */
    uint32_t firmware_version;       /* Firmware version */
    uint32_t resources_used;          /* Resources used */
    uint32_t resources_available;     /* Resources available */
    uint32_t interrupt_line;         /* Interrupt line */
    uint32_t dma_channel;            /* DMA channel */
    uint32_t io_base;                /* I/O base address */
    uint32_t io_range;               /* I/O address range */
    uint32_t memory_base;            /* Memory base address */
    uint32_t memory_range;           /* Memory address range */
    int active;                      /* 1 if active, 0 if inactive */
} device_info_t;

/* System Information Structure */
typedef struct {
    /* CPU Information */
    char cpu_vendor[16];             /* CPU vendor string */
    char cpu_model[64];              /* CPU model string */
    uint32_t cpu_speed;              /* CPU speed in MHz */
    uint8_t cpu_cores;                /* Number of cores */
    uint8_t cpu_threads;             /* Number of threads */
    uint8_t cpu_state;               /* CPU state */
    uint32_t cpu_usage;              /* CPU usage percentage */
    uint32_t cpu_temperature;        /* CPU temperature in Celsius */
    uint32_t cpu_voltage;            /* CPU voltage in millivolts */
    
    /* Memory Information */
    uint32_t total_memory;           /* Total memory in KB */
    uint32_t available_memory;       /* Available memory in KB */
    uint32_t used_memory;            /* Used memory in KB */
    uint32_t cached_memory;          /* Cached memory in KB */
    uint32_t buffer_memory;          /* Buffer memory in KB */
    uint32_t swap_total;             /* Total swap in KB */
    uint32_t swap_used;              /* Used swap in KB */
    uint32_t swap_free;              /* Free swap in KB */
    
    /* Process Information */
    uint32_t process_count;          /* Number of processes */
    uint32_t thread_count;           /* Number of threads */
    uint32_t active_processes;       /* Number of active processes */
    uint32_t zombie_processes;       /* Number of zombie processes */
    
    /* Device Information */
    uint32_t device_count;           /* Number of devices */
    uint32_t active_devices;         /* Number of active devices */
    
    /* System Information */
    uint32_t uptime;                 /* System uptime in seconds */
    uint32_t boot_time;              /* Boot time */
    uint8_t power_state;             /* Power state */
    uint32_t battery_level;          /* Battery level percentage */
    uint32_t ac_power;               /* 1 if on AC power, 0 if on battery */
    
    /* Network Information */
    uint32_t network_interfaces;     /* Number of network interfaces */
    uint32_t bytes_sent;             /* Bytes sent */
    uint32_t bytes_received;         /* Bytes received */
    uint32_t packets_sent;           /* Packets sent */
    uint32_t packets_received;       /* Packets received */
    
    /* Disk Information */
    uint32_t disk_count;             /* Number of disks */
    uint32_t total_disk_space;       /* Total disk space in MB */
    uint32_t used_disk_space;        /* Used disk space in MB */
    uint32_t free_disk_space;        /* Free disk space in MB */
    
    /* Graphics Information */
    uint32_t graphics_memory;        /* Graphics memory in MB */
    uint32_t screen_width;           /* Screen width */
    uint32_t screen_height;          /* Screen height */
    uint32_t screen_bpp;             /* Screen bits per pixel */
    uint32_t refresh_rate;           /* Refresh rate in Hz */
    
    /* Audio Information */
    uint32_t audio_devices;          /* Number of audio devices */
    uint32_t sample_rate;            /* Sample rate in Hz */
    uint32_t bit_depth;              /* Bit depth */
    uint32_t channels;               /* Number of channels */
} system_info_t;

/* Event Structure */
typedef struct {
    uint32_t event_id;               /* Event ID */
    uint8_t event_type;              /* Event type */
    uint32_t timestamp;              /* Event timestamp */
    uint32_t source_pid;             /* Source process ID */
    char description[256];           /* Event description */
    void* data;                      /* Event data */
} system_event_t;

/* Performance Counter Structure */
typedef struct {
    uint32_t counter_id;             /* Counter ID */
    char name[64];                   /* Counter name */
    char description[256];           /* Description */
    uint64_t value;                  /* Counter value */
    uint64_t delta;                  /* Delta since last read */
    uint32_t timestamp;              /* Last update timestamp */
} performance_counter_t;

/* Function Prototypes */

/* System Management */
int sys_init(void);
int sys_shutdown(void);
int sys_get_info(system_info_t* info);
int sys_update_info(void);
int sys_get_uptime(uint32_t* uptime);
int sys_get_boot_time(uint32_t* boot_time);
int sys_get_load_average(float* load1, float* load5, float* load15);

/* Process Management */
int sys_create_process(const char* name, const char* path, uint32_t* pid);
int sys_terminate_process(uint32_t pid, int exit_code);
int sys_suspend_process(uint32_t pid);
int sys_resume_process(uint32_t pid);
int sys_get_process_info(uint32_t pid, process_info_t* info);
int sys_set_process_priority(uint32_t pid, uint8_t priority);
int sys_list_processes(process_info_t** processes, uint32_t* count);
int sys_find_process_by_name(const char* name, uint32_t* pid);
int sys_wait_for_process(uint32_t pid, int* exit_code);
int sys_get_process_memory_usage(uint32_t pid, uint32_t* memory_usage);
int sys_get_process_cpu_usage(uint32_t pid, float* cpu_usage);

/* Memory Management */
int sys_allocate_memory(uint32_t size, uint32_t* address, uint8_t type);
int sys_free_memory(uint32_t address);
int sys_protect_memory(uint32_t address, uint32_t size, uint8_t protection);
int sys_get_memory_info(memory_region_t** regions, uint32_t* count);
int sys_get_memory_usage(uint32_t* total, uint32_t* used, uint32_t* free);
int sys_get_memory_statistics(uint32_t* total, uint32_t* available, uint32_t* cached, uint32_t* buffers);
int sys_defragment_memory(void);
int sys_flush_memory_caches(void);

/* Device Management */
int sys_register_device(uint8_t type, const char* name, const char* description);
int sys_unregister_device(uint8_t type, const char* name);
int sys_get_device_info(uint8_t type, const char* name, device_info_t* info);
int sys_list_devices(device_info_t** devices, uint32_t* count);
int sys_enable_device(uint8_t type, const char* name);
int sys_disable_device(uint8_t type, const char* name);
int sys_get_device_status(uint8_t type, const char* name, uint8_t* status);
int sys_set_device_configuration(uint8_t type, const char* name, const void* config);

/* Power Management */
int sys_shutdown_system(int timeout);
int sys_reboot_system(int timeout);
int sys_hibernate_system(void);
int sys_suspend_system(void);
int sys_get_power_state(uint8_t* state);
int sys_set_power_state(uint8_t state);
int sys_get_battery_info(uint32_t* level, uint32_t* time_remaining, uint8_t* charging);
int sys_set_power_policy(uint8_t policy);

/* Event Management */
int sys_log_event(uint8_t event_type, uint32_t source_pid, const char* description);
int sys_get_event(uint32_t event_id, system_event_t* event);
int sys_list_events(system_event_t** events, uint32_t* count);
int sys_clear_events(void);
int sys_set_event_filter(uint8_t event_type);
int sys_enable_event_logging(uint8_t enable);

/* Performance Monitoring */
int sys_create_performance_counter(const char* name, const char* description, uint32_t* counter_id);
int sys_delete_performance_counter(uint32_t counter_id);
int sys_update_performance_counter(uint32_t counter_id, uint64_t value);
int sys_get_performance_counter(uint32_t counter_id, performance_counter_t* counter);
int sys_list_performance_counters(performance_counter_t** counters, uint32_t* count);
int sys_reset_performance_counters(void);

/* System Configuration */
int sys_get_system_config(const char* key, char* value);
int sys_set_system_config(const char* key, const char* value);
int sys_load_system_config(const char* filename);
int sys_save_system_config(const char* filename);
int sys_reset_system_config(void);

/* System Diagnostics */
int sys_run_diagnostics(uint8_t test_type);
int sys_get_diagnostic_results(uint8_t test_type, char* results);
int sys_generate_system_report(char* report);
int sys_validate_system_integrity(void);
int sys_check_system_health(void);

/* System Services */
int sys_start_service(const char* name);
int sys_stop_service(const char* name);
int sys_restart_service(const char* name);
int sys_get_service_status(const char* name, uint8_t* status);
int sys_list_services(char** services, uint32_t* count);

/* System Security */
int sys_create_user(const char* username, const char* password);
int sys_delete_user(const char* username);
int sys_authenticate_user(const char* username, const char* password, uint32_t* user_id);
int sys_set_user_permissions(uint32_t user_id, uint32_t permissions);
int sys_get_user_permissions(uint32_t user_id, uint32_t* permissions);

/* Error Codes */
#define SYS_SUCCESS                 0
#define SYS_ERROR_INVALID_PARAMETER 1
#define SYS_ERROR_NOT_FOUND        2
#define SYS_ERROR_ACCESS_DENIED    3
#define SYS_ERROR_ALREADY_EXISTS   4
#define SYS_ERROR_NOT_ENOUGH_MEMORY 5
#define SYS_ERROR_INSUFFICIENT_RESOURCES 6
#define SYS_ERROR_DEVICE_BUSY      7
#define SYS_ERROR_DEVICE_NOT_READY 8
#define SYS_ERROR_DEVICE_ERROR    9
#define SYS_ERROR_PROCESS_NOT_FOUND 10
#define SYS_ERROR_PROCESS_RUNNING 11
#define SYS_ERROR_PROCESS_TERMINATED 12
#define SYS_ERROR_MEMORY_NOT_FOUND 13
#define SYS_ERROR_MEMORY_CORRUPT 14
#define SYS_ERROR_SYSTEM_ERROR    15
#define SYS_ERROR_TIMEOUT         16
#define SYS_ERROR_NOT_IMPLEMENTED  17

/* Memory Protection Flags */
#define MEM_PROTECTION_READ        0x01
#define MEM_PROTECTION_WRITE       0x02
#define MEM_PROTECTION_EXECUTE      0x04
#define MEM_PROTECTION_ALL         0x07

/* Process Priority Levels */
#define PRIORITY_IDLE              0
#define PRIORITY_LOW               4
#define PRIORITY_NORMAL            8
#define PRIORITY_HIGH              12
#define PRIORITY_REALTIME          16
#define PRIORITY_CRITICAL          20
#define PRIORITY_MAXIMUM           31

/* Power Policies */
#define POWER_POLICY_PERFORMANCE   0
#define POWER_POLICY_BALANCED      1
#define POWER_POLICY_POWERSAVE     2

/* Event Types */
#define EVENT_ALL                  0xFF

#endif /* KSDOS_SYSTEM_H */
