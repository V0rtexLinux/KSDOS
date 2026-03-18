/* ================================================================
   KSDOS OpenGL Context Manager
   Manages multiple OpenGL contexts and rendering states
   ================================================================ */

#include "opengl.h"

/* Maximum number of contexts */
#define MAX_CONTEXTS 8

/* Context structure */
typedef struct {
    GLuint id;
    GLboolean active;
    GLboolean hardware_accelerated;
    
    /* Framebuffer info */
    void* framebuffer;
    int width, height, bpp;
    
    /* Context state (copy of GLcontext) */
    GLcontext gl_state;
    
    /* Performance statistics */
    GLuint draw_calls;
    GLuint triangles_rendered;
    GLuint frames_rendered;
    GLfloat total_render_time;
    
} gl_context_manager_t;

/* Global context manager */
static gl_context_manager_t context_manager[MAX_CONTEXTS];
static GLuint current_context_id = 0;
static GLuint next_context_id = 1;
static GLboolean context_manager_initialized = GL_FALSE;

/* ================================================================ */
/* Context Manager Initialization                                     */
/* ================================================================ */

void gl_context_manager_init(void) {
    if (context_manager_initialized) return;
    
    /* Initialize all contexts to inactive */
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        context_manager[i].id = 0;
        context_manager[i].active = GL_FALSE;
        context_manager[i].hardware_accelerated = GL_FALSE;
        context_manager[i].framebuffer = NULL;
        context_manager[i].width = 0;
        context_manager[i].height = 0;
        context_manager[i].bpp = 0;
        context_manager[i].draw_calls = 0;
        context_manager[i].triangles_rendered = 0;
        context_manager[i].frames_rendered = 0;
        context_manager[i].total_render_time = 0.0f;
    }
    
    context_manager_initialized = GL_TRUE;
}

void gl_context_manager_shutdown(void) {
    if (!context_manager_initialized) return;
    
    /* Destroy all active contexts */
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active) {
            gl_destroy_context(context_manager[i].id);
        }
    }
    
    context_manager_initialized = GL_FALSE;
}

/* ================================================================ */
/* Context Creation and Destruction                                   */
/* ================================================================ */

GLuint gl_create_context(void* framebuffer, int width, int height, int bpp) {
    if (!context_manager_initialized) {
        gl_context_manager_init();
    }
    
    /* Find free context slot */
    int slot = -1;
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (!context_manager[i].active) {
            slot = i;
            break;
        }
    }
    
    if (slot == -1) {
        return 0;  /* No free contexts */
    }
    
    /* Initialize context */
    gl_context_manager_t* ctx = &context_manager[slot];
    ctx->id = next_context_id++;
    ctx->active = GL_TRUE;
    ctx->framebuffer = framebuffer;
    ctx->width = width;
    ctx->height = height;
    ctx->bpp = bpp;
    
    /* Check for hardware acceleration */
    ctx->hardware_accelerated = gl_hardware_available();
    
    /* Initialize OpenGL state */
    gl_init();
    ctx->gl_state = *((GLcontext*)0);  /* Copy global context state */
    
    /* Setup framebuffer */
    gl_ksdos_set_framebuffer(framebuffer, width, height);
    
    /* Initialize hardware if available */
    if (ctx->hardware_accelerated) {
        gl_hardware_set_context(framebuffer, width, height, bpp);
    }
    
    /* Reset statistics */
    ctx->draw_calls = 0;
    ctx->triangles_rendered = 0;
    ctx->frames_rendered = 0;
    ctx->total_render_time = 0.0f;
    
    return ctx->id;
}

GLboolean gl_destroy_context(GLuint context_id) {
    if (!context_manager_initialized) return GL_FALSE;
    
    /* Find context */
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].id == context_id) {
            /* Shutdown hardware if needed */
            if (context_manager[i].hardware_accelerated) {
                /* Hardware cleanup for this context */
            }
            
            /* Mark as inactive */
            context_manager[i].active = GL_FALSE;
            
            /* If this was the current context, switch to default */
            if (current_context_id == context_id) {
                current_context_id = 0;
            }
            
            return GL_TRUE;
        }
    }
    
    return GL_FALSE;
}

/* ================================================================ */
/* Context Management                                                */
/* ================================================================ */

GLboolean gl_make_current(GLuint context_id) {
    if (!context_manager_initialized) return GL_FALSE;
    
    if (context_id == 0) {
        /* Make default context current */
        current_context_id = 0;
        return GL_TRUE;
    }
    
    /* Find context */
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].id == context_id) {
            /* Switch to this context */
            current_context_id = context_id;
            
            /* Update global OpenGL state */
            /* In a real implementation, this would switch the global context */
            
            /* Setup framebuffer for this context */
            gl_ksdos_set_framebuffer(context_manager[i].framebuffer, 
                                   context_manager[i].width, 
                                   context_manager[i].height);
            
            /* Setup hardware if needed */
            if (context_manager[i].hardware_accelerated) {
                gl_hardware_set_context(context_manager[i].framebuffer,
                                      context_manager[i].width,
                                      context_manager[i].height,
                                      context_manager[i].bpp);
            }
            
            return GL_TRUE;
        }
    }
    
    return GL_FALSE;
}

GLuint gl_get_current_context(void) {
    return current_context_id;
}

/* ================================================================ */
/* Context Information                                               */
/* ================================================================ */

GLboolean gl_get_context_info(GLuint context_id, int* width, int* height, 
                             int* bpp, GLboolean* hardware_accelerated) {
    if (!context_manager_initialized) return GL_FALSE;
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].id == context_id) {
            if (width) *width = context_manager[i].width;
            if (height) *height = context_manager[i].height;
            if (bpp) *bpp = context_manager[i].bpp;
            if (hardware_accelerated) *hardware_accelerated = context_manager[i].hardware_accelerated;
            return GL_TRUE;
        }
    }
    
    return GL_FALSE;
}

/* ================================================================ */
/* Context Performance Monitoring                                     */
/* ================================================================ */

void gl_context_begin_frame(GLuint context_id) {
    if (!context_manager_initialized) return;
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].id == context_id) {
            /* Start frame timing */
            /* In a real implementation, this would use high-precision timers */
            context_manager[i].frames_rendered++;
            break;
        }
    }
}

void gl_context_end_frame(GLuint context_id) {
    if (!context_manager_initialized) return;
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].id == context_id) {
            /* End frame timing and update statistics */
            /* In a real implementation, this would calculate frame time */
            break;
        }
    }
}

void gl_context_record_draw_call(GLuint context_id, GLenum primitive_type, GLuint count) {
    if (!context_manager_initialized) return;
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].id == context_id) {
            context_manager[i].draw_calls++;
            
            /* Estimate triangles based on primitive type */
            switch (primitive_type) {
                case GL_TRIANGLES:
                    context_manager[i].triangles_rendered += count / 3;
                    break;
                case GL_TRIANGLE_STRIP:
                case GL_TRIANGLE_FAN:
                    context_manager[i].triangles_rendered += count - 2;
                    break;
                case GL_QUADS:
                    context_manager[i].triangles_rendered += (count / 4) * 2;
                    break;
                case GL_QUAD_STRIP:
                    context_manager[i].triangles_rendered += (count - 2) * 2;
                    break;
            }
            break;
        }
    }
}

/* ================================================================ */
/* Context Statistics                                                */
/* ================================================================ */

typedef struct {
    GLuint active_contexts;
    GLuint total_draw_calls;
    GLuint total_triangles;
    GLuint total_frames;
    GLfloat average_frame_time;
    GLboolean hardware_available;
} gl_context_stats_t;

void gl_context_get_statistics(gl_context_stats_t* stats) {
    if (!context_manager_initialized || !stats) return;
    
    stats->active_contexts = 0;
    stats->total_draw_calls = 0;
    stats->total_triangles = 0;
    stats->total_frames = 0;
    stats->average_frame_time = 0.0f;
    stats->hardware_available = gl_hardware_available();
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active) {
            stats->active_contexts++;
            stats->total_draw_calls += context_manager[i].draw_calls;
            stats->total_triangles += context_manager[i].triangles_rendered;
            stats->total_frames += context_manager[i].frames_rendered;
            stats->average_frame_time += context_manager[i].total_render_time;
        }
    }
    
    if (stats->total_frames > 0) {
        stats->average_frame_time /= stats->total_frames;
    }
}

/* ================================================================ */
/* Context Sharing                                                   */
/* ================================================================ */

GLboolean gl_share_context(GLuint context_id1, GLuint context_id2) {
    /* Share resources between contexts */
    /* In a real implementation, this would share textures, VBOs, etc. */
    if (!context_manager_initialized) return GL_FALSE;
    
    /* Find both contexts */
    gl_context_manager_t* ctx1 = NULL;
    gl_context_manager_t* ctx2 = NULL;
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active) {
            if (context_manager[i].id == context_id1) ctx1 = &context_manager[i];
            if (context_manager[i].id == context_id2) ctx2 = &context_manager[i];
        }
    }
    
    if (!ctx1 || !ctx2) return GL_FALSE;
    
    /* Share resources (simplified) */
    /* In a real implementation, this would link texture objects, VBOs, etc. */
    
    return GL_TRUE;
}

/* ================================================================ */
/* Context Validation                                                */
/* ================================================================ */

GLboolean gl_validate_context(GLuint context_id) {
    if (!context_manager_initialized) return GL_FALSE;
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].id == context_id) {
            /* Validate context state */
            /* Check framebuffer, hardware state, etc. */
            return GL_TRUE;
        }
    }
    
    return GL_FALSE;
}

/* ================================================================ */
/* Context Debug Functions                                           */
/* ================================================================ */

void gl_context_dump_info(GLuint context_id) {
    if (!context_manager_initialized) return;
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].id == context_id) {
            /* Dump context information for debugging */
            /* This would print detailed context state */
            break;
        }
    }
}

void gl_context_dump_all(void) {
    if (!context_manager_initialized) return;
    
    /* Dump information for all active contexts */
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active) {
            gl_context_dump_info(context_manager[i].id);
        }
    }
}

/* ================================================================ */
/* Context Utility Functions                                         */
/* ================================================================ */

GLuint gl_find_context_by_framebuffer(void* framebuffer) {
    if (!context_manager_initialized) return 0;
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].framebuffer == framebuffer) {
            return context_manager[i].id;
        }
    }
    
    return 0;
}

GLboolean gl_resize_context(GLuint context_id, int new_width, int new_height) {
    if (!context_manager_initialized) return GL_FALSE;
    
    for (int i = 0; i < MAX_CONTEXTS; i++) {
        if (context_manager[i].active && context_manager[i].id == context_id) {
            /* Resize context */
            context_manager[i].width = new_width;
            context_manager[i].height = new_height;
            
            /* Update OpenGL viewport */
            gl_viewport(0, 0, new_width, new_height);
            
            /* Update hardware if needed */
            if (context_manager[i].hardware_accelerated) {
                gl_hardware_set_context(context_manager[i].framebuffer,
                                      new_width, new_height,
                                      context_manager[i].bpp);
            }
            
            return GL_TRUE;
        }
    }
    
    return GL_FALSE;
}
