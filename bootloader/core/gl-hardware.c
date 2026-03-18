/* ================================================================
   KSDOS OpenGL Hardware Acceleration Layer
   VBE/Bochs hardware acceleration for real OpenGL performance
   ================================================================ */

#include "opengl.h"

/* Hardware acceleration constants */
#define VBE_DISPI_INDEX_ENABLE        0x01
#define VBE_DISPI_INDEX_XRES          0x02
#define VBE_DISPI_INDEX_YRES          0x03
#define VBE_DISPI_INDEX_BPP           0x04
#define VBE_DISPI_INDEX_BANK          0x05
#define VBE_DISPI_INDEX_VIRT_WIDTH    0x06
#define VBE_DISPI_INDEX_VIRT_HEIGHT   0x07
#define VBE_DISPI_INDEX_X_OFFSET      0x08
#define VBE_DISPI_INDEX_Y_OFFSET      0x09
#define VBE_DISPI_INDEX_ENABLE_3D     0x0A
#define VBE_DISPI_INDEX_3D_COMMAND    0x0B
#define VBE_DISPI_INDEX_3D_DATA       0x0C

#define VBE_DISPI_3D_CMD_TRIANGLE     0x01
#define VBE_DISPI_3D_CMD_LINE         0x02
#define VBE_DISPI_3D_CMD_CLEAR        0x03
#define VBE_DISPI_3D_CMD_TEXTURE      0x04

/* Hardware state */
static struct {
    GLboolean initialized;
    GLboolean supports_3d;
    GLuint* command_buffer;
    GLuint* data_buffer;
    GLuint buffer_size;
    void* framebuffer;
    int width, height, bpp;
    GLuint current_texture;
} hw_state = {0};

/* Hardware I/O functions */
static void hw_outw(unsigned short port, unsigned short val) {
    __asm__ volatile ("outw %0,%1"::"a"(val),"Nd"(port));
}

static unsigned short hw_inw(unsigned short port) {
    unsigned short val;
    __asm__ volatile ("inw %1,%0":"=a"(val):"Nd"(port));
    return val;
}

static void hw_outd(unsigned short port, unsigned int val) {
    __asm__ volatile ("outl %0,%1"::"a"(val),"Nd"(port));
}

static unsigned int hw_ind(unsigned short port) {
    unsigned int val;
    __asm__ volatile ("inl %1,%0":"=a"(val):"Nd"(port));
    return val;
}

/* ================================================================ */
/* Hardware Detection and Initialization                              */
/* ================================================================ */

GLboolean gl_hardware_available(void) {
    /* Check for VBE 3.0+ with 3D acceleration support */
    /* Try to detect Bochs VBE with 3D extensions */
    
    /* Save current VBE state */
    unsigned short old_enable = hw_inw(0x01CE);
    
    /* Try to enable 3D mode */
    hw_outw(0x01CE, VBE_DISPI_INDEX_ENABLE_3D);
    hw_outw(0x01CF, 0x0001);
    
    /* Check if 3D mode was accepted */
    unsigned short enable_3d = hw_inw(0x01CF);
    
    /* Restore original state */
    hw_outw(0x01CE, VBE_DISPI_INDEX_ENABLE);
    hw_outw(0x01CF, old_enable);
    
    return (enable_3d & 0x0001) ? GL_TRUE : GL_FALSE;
}

void gl_hardware_init(void) {
    if (hw_state.initialized) return;
    
    /* Initialize VBE hardware acceleration */
    hw_state.supports_3d = gl_hardware_available();
    
    if (hw_state.supports_3d) {
        /* Allocate command and data buffers */
        hw_state.buffer_size = 65536;  /* 64KB buffers */
        
        /* In a real implementation, these would be allocated in video memory */
        /* For now, use regular memory */
        hw_state.command_buffer = (GLuint*)0xE0000000;  /* High memory area */
        hw_state.data_buffer = (GLuint*)0xE0010000;
        
        /* Enable 3D acceleration */
        hw_outw(0x01CE, VBE_DISPI_INDEX_ENABLE_3D);
        hw_outw(0x01CF, 0x0001);
        
        hw_state.initialized = GL_TRUE;
    }
}

void gl_hardware_shutdown(void) {
    if (!hw_state.initialized) return;
    
    /* Disable 3D acceleration */
    hw_outw(0x01CE, VBE_DISPI_INDEX_ENABLE_3D);
    hw_outw(0x01CF, 0x0000);
    
    hw_state.initialized = GL_FALSE;
}

/* ================================================================ */
/* Hardware-Accelerated Primitive Functions                          */
/* ================================================================ */

void gl_hardware_clear(GLuint color) {
    if (!hw_state.supports_3d || !hw_state.initialized) return;
    
    /* Send clear command to hardware */
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_COMMAND);
    hw_outw(0x01CF, VBE_DISPI_3D_CMD_CLEAR);
    
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_DATA);
    hw_outd(0x01CF, color);
    
    /* Wait for completion */
    while (hw_inw(0x01CF) & 0x8000) {
        /* Wait for hardware */
    }
}

void gl_hardware_triangle(const GLvertex* v1, const GLvertex* v2, const GLvertex* v3) {
    if (!hw_state.supports_3d || !hw_state.initialized) return;
    
    /* Pack triangle data into command buffer */
    GLuint* cmd = hw_state.command_buffer;
    int index = 0;
    
    /* Command header */
    cmd[index++] = VBE_DISPI_3D_CMD_TRIANGLE;
    
    /* Vertex 1 */
    cmd[index++] = *(GLuint*)&v1->position.x;
    cmd[index++] = *(GLuint*)&v1->position.y;
    cmd[index++] = *(GLuint*)&v1->position.z;
    cmd[index++] = gl_pack_color(&v1->color);
    
    /* Vertex 2 */
    cmd[index++] = *(GLuint*)&v2->position.x;
    cmd[index++] = *(GLuint*)&v2->position.y;
    cmd[index++] = *(GLuint*)&v2->position.z;
    cmd[index++] = gl_pack_color(&v2->color);
    
    /* Vertex 3 */
    cmd[index++] = *(GLuint*)&v3->position.x;
    cmd[index++] = *(GLuint*)&v3->position.y;
    cmd[index++] = *(GLuint*)&v3->position.z;
    cmd[index++] = gl_pack_color(&v3->color);
    
    /* Send command to hardware */
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_COMMAND);
    hw_outw(0x01CF, VBE_DISPI_3D_CMD_TRIANGLE);
    
    /* Send data pointer */
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_DATA);
    hw_outd(0x01CF, (GLuint)cmd);
    
    /* Wait for completion */
    while (hw_inw(0x01CF) & 0x8000) {
        /* Wait for hardware */
    }
}

void gl_hardware_line(const GLvertex* v1, const GLvertex* v2) {
    if (!hw_state.supports_3d || !hw_state.initialized) return;
    
    /* Pack line data into command buffer */
    GLuint* cmd = hw_state.command_buffer;
    int index = 0;
    
    /* Command header */
    cmd[index++] = VBE_DISPI_3D_CMD_LINE;
    
    /* Vertex 1 */
    cmd[index++] = *(GLuint*)&v1->position.x;
    cmd[index++] = *(GLuint*)&v1->position.y;
    cmd[index++] = *(GLuint*)&v1->position.z;
    cmd[index++] = gl_pack_color(&v1->color);
    
    /* Vertex 2 */
    cmd[index++] = *(GLuint*)&v2->position.x;
    cmd[index++] = *(GLuint*)&v2->position.y;
    cmd[index++] = *(GLuint*)&v2->position.z;
    cmd[index++] = gl_pack_color(&v2->color);
    
    /* Send command to hardware */
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_COMMAND);
    hw_outw(0x01CF, VBE_DISPI_3D_CMD_LINE);
    
    /* Send data pointer */
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_DATA);
    hw_outd(0x01CF, (GLuint)cmd);
    
    /* Wait for completion */
    while (hw_inw(0x01CF) & 0x8000) {
        /* Wait for hardware */
    }
}

/* ================================================================ */
/* Hardware Texture Support                                          */
/* ================================================================ */

void gl_hardware_upload_texture(GLuint width, GLuint height, const void* data) {
    if (!hw_state.supports_3d || !hw_state.initialized) return;
    
    /* Send texture upload command */
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_COMMAND);
    hw_outw(0x01CF, VBE_DISPI_3D_CMD_TEXTURE);
    
    /* Send texture parameters */
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_DATA);
    hw_outd(0x01CF, width);
    
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_DATA);
    hw_outd(0x01CF, height);
    
    /* Send texture data pointer */
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_DATA);
    hw_outd(0x01CF, (GLuint)data);
    
    /* Wait for completion */
    while (hw_inw(0x01CF) & 0x8000) {
        /* Wait for hardware */
    }
}

void gl_hardware_bind_texture(GLuint texture_id) {
    if (!hw_state.supports_3d || !hw_state.initialized) return;
    
    hw_state.current_texture = texture_id;
    
    /* Send texture bind command */
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_COMMAND);
    hw_outw(0x01CF, 0x0005);  /* Bind texture command */
    
    hw_outw(0x01CE, VBE_DISPI_INDEX_3D_DATA);
    hw_outd(0x01CF, texture_id);
    
    /* Wait for completion */
    while (hw_inw(0x01CF) & 0x8000) {
        /* Wait for hardware */
    }
}

/* ================================================================ */
/* Hardware Performance Monitoring                                     */
/* ================================================================ */

typedef struct {
    GLuint triangles_rendered;
    GLuint lines_rendered;
    GLuint points_rendered;
    GLuint texture_uploads;
    GLuint clear_operations;
    GLfloat render_time_ms;
} gl_hardware_stats_t;

static gl_hardware_stats_t hw_stats = {0};

void gl_hardware_begin_stats(void) {
    /* Reset statistics */
    hw_stats.triangles_rendered = 0;
    hw_stats.lines_rendered = 0;
    hw_stats.points_rendered = 0;
    hw_stats.texture_uploads = 0;
    hw_stats.clear_operations = 0;
    
    /* Start timing (simplified) */
    /* In a real implementation, this would use high-precision timers */
}

void gl_hardware_end_stats(void) {
    /* End timing and calculate performance metrics */
    /* This would read hardware performance counters */
}

gl_hardware_stats_t* gl_hardware_get_stats(void) {
    return &hw_stats;
}

/* ================================================================ */
/* Hardware Acceleration Fallback                                     */
/* ================================================================ */

void gl_hardware_fallback_clear(GLuint color) {
    /* Software clear fallback */
    if (hw_state.framebuffer) {
        for (int i = 0; i < hw_state.width * hw_state.height; i++) {
            ((GLuint*)hw_state.framebuffer)[i] = color;
        }
    }
}

void gl_hardware_fallback_triangle(const GLvertex* v1, const GLvertex* v2, const GLvertex* v3) {
    /* Software triangle fallback */
    /* This would call the software rasterizer */
    extern void gl_rasterize_triangle(const GLvertex*, const GLvertex*, const GLvertex*);
    gl_rasterize_triangle(v1, v2, v3);
}

void gl_hardware_fallback_line(const GLvertex* v1, const GLvertex* v2) {
    /* Software line fallback */
    extern void gl_rasterize_line(const GLvertex*, const GLvertex*);
    gl_rasterize_line(v1, v2);
}

/* ================================================================ */
/* Hardware Context Management                                        */
/* ================================================================ */

void gl_hardware_set_context(void* framebuffer, int width, int height, int bpp) {
    hw_state.framebuffer = framebuffer;
    hw_state.width = width;
    hw_state.height = height;
    hw_state.bpp = bpp;
    
    /* Configure VBE for hardware acceleration */
    if (hw_state.supports_3d && hw_state.initialized) {
        /* Set resolution */
        hw_outw(0x01CE, VBE_DISPI_INDEX_XRES);
        hw_outw(0x01CF, width);
        
        hw_outw(0x01CE, VBE_DISPI_INDEX_YRES);
        hw_outw(0x01CF, height);
        
        hw_outw(0x01CE, VBE_DISPI_INDEX_BPP);
        hw_outw(0x01CF, bpp);
        
        /* Enable hardware acceleration */
        hw_outw(0x01CE, VBE_DISPI_INDEX_ENABLE);
        hw_outw(0x01CF, 0x0001);  /* Enable */
    }
}

void gl_hardware_get_capabilities(GLboolean* supports_3d, GLboolean* supports_textures, 
                                 GLboolean* supports_blending, GLboolean* supports_depth) {
    if (supports_3d) *supports_3d = hw_state.supports_3d;
    if (supports_textures) *supports_textures = hw_state.supports_3d;  /* 3D implies textures */
    if (supports_blending) *supports_blending = GL_TRUE;  /* Always supported */
    if (supports_depth) *supports_depth = hw_state.supports_3d;  /* 3D implies depth */
}

/* ================================================================ */
/* Hardware Debug Functions                                          */
/* ================================================================ */

void gl_hardware_dump_state(void) {
    /* Debug function to dump hardware state */
    /* This would be used for debugging hardware acceleration issues */
}

void gl_hardware_reset(void) {
    /* Reset hardware acceleration state */
    gl_hardware_shutdown();
    gl_hardware_init();
}
