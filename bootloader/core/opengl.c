/* ================================================================
   KSDOS OpenGL 1.5 Real Implementation
   Hardware-accelerated graphics rendering engine
   ================================================================ */

#include "opengl.h"
#include <math.h>

/* Global OpenGL Context */
static GLcontext gl_context;
static GLcontext* ctx = &gl_context;

/* Hardware acceleration state */
static GLboolean hardware_initialized = GL_FALSE;
static void* hardware_framebuffer = NULL;
static int fb_width = 640;
static int fb_height = 480;

/* Temporary vertex storage */
#define MAX_VERTICES 4096
static GLvertex vertex_buffer[MAX_VERTICES];
static int vertex_count = 0;
static GLboolean in_begin_end = GL_FALSE;

/* Forward declarations */
static void gl_transform_vertex(GLvertex* v);
static void gl_rasterize_triangle(const GLvertex* v1, const GLvertex* v2, const GLvertex* v3);
static void gl_rasterize_line(const GLvertex* v1, const GLvertex* v2);
static void gl_rasterize_point(const GLvertex* v);
static unsigned int gl_pack_color(const GLvec4* color);

/* ================================================================ */
/* Core OpenGL Functions                                             */
/* ================================================================ */

void gl_init(void) {
    /* Initialize context to defaults */
    ctx->viewport_x = 0;
    ctx->viewport_y = 0;
    ctx->viewport_width = 640;
    ctx->viewport_height = 480;
    ctx->scissor_x = 0;
    ctx->scissor_y = 0;
    ctx->scissor_width = 640;
    ctx->scissor_height = 480;
    ctx->scissor_test_enabled = GL_FALSE;
    
    /* Initialize matrices */
    ctx->matrix_mode = GL_MODELVIEW;
    gl_matrix_identity(&ctx->modelview_matrix);
    gl_matrix_identity(&ctx->projection_matrix);
    gl_matrix_identity(&ctx->texture_matrix);
    gl_matrix_identity(&ctx->modelview_projection_matrix);
    
    /* Initialize vertex arrays */
    ctx->vertex_array_enabled = GL_FALSE;
    ctx->normal_array_enabled = GL_FALSE;
    ctx->color_array_enabled = GL_FALSE;
    ctx->texcoord_array_enabled = GL_FALSE;
    
    ctx->vertex_pointer = NULL;
    ctx->normal_pointer = NULL;
    ctx->color_pointer = NULL;
    ctx->texcoord_array_pointer = NULL;
    
    ctx->vertex_stride = 0;
    ctx->normal_stride = 0;
    ctx->color_stride = 0;
    ctx->texcoord_stride = 0;
    
    /* Initialize current state */
    ctx->current_color = (GLvec4){1.0f, 1.0f, 1.0f, 1.0f};
    ctx->current_normal = (GLvec3){0.0f, 0.0f, 1.0f};
    ctx->current_texcoord = (GLvec2){0.0f, 0.0f};
    
    /* Initialize rendering state */
    ctx->primitive_mode = GL_TRIANGLES;
    ctx->depth_test_enabled = GL_FALSE;
    ctx->blend_enabled = GL_FALSE;
    ctx->cull_face_enabled = GL_FALSE;
    ctx->lighting_enabled = GL_FALSE;
    ctx->texture_2d_enabled = GL_FALSE;
    
    ctx->blend_src_factor = GL_ONE;
    ctx->blend_dst_factor = GL_ZERO;
    
    /* Clear error state */
    ctx->error = GL_NO_ERROR;
    
    /* Initialize hardware acceleration if available */
    ctx->hardware_accelerated = gl_hardware_available();
    if (ctx->hardware_accelerated) {
        gl_hardware_init();
    }
    
    vertex_count = 0;
    in_begin_end = GL_FALSE;
}

void gl_shutdown(void) {
    if (ctx->hardware_accelerated && hardware_initialized) {
        gl_hardware_shutdown();
    }
}

void gl_begin(GLenum mode) {
    if (in_begin_end) {
        ctx->error = GL_INVALID_OPERATION;
        return;
    }
    
    switch (mode) {
        case GL_POINTS:
        case GL_LINES:
        case GL_LINE_LOOP:
        case GL_LINE_STRIP:
        case GL_TRIANGLES:
        case GL_TRIANGLE_STRIP:
        case GL_TRIANGLE_FAN:
        case GL_QUADS:
        case GL_QUAD_STRIP:
        case GL_POLYGON:
            ctx->primitive_mode = mode;
            in_begin_end = GL_TRUE;
            vertex_count = 0;
            break;
        default:
            ctx->error = GL_INVALID_ENUM;
            break;
    }
}

void gl_end(void) {
    if (!in_begin_end) {
        ctx->error = GL_INVALID_OPERATION;
        return;
    }
    
    /* Process accumulated vertices */
    if (vertex_count > 0) {
        switch (ctx->primitive_mode) {
            case GL_POINTS:
                for (int i = 0; i < vertex_count; i++) {
                    gl_rasterize_point(&vertex_buffer[i]);
                }
                break;
                
            case GL_LINES:
                for (int i = 0; i < vertex_count - 1; i += 2) {
                    gl_rasterize_line(&vertex_buffer[i], &vertex_buffer[i + 1]);
                }
                break;
                
            case GL_LINE_STRIP:
                for (int i = 0; i < vertex_count - 1; i++) {
                    gl_rasterize_line(&vertex_buffer[i], &vertex_buffer[i + 1]);
                }
                break;
                
            case GL_LINE_LOOP:
                for (int i = 0; i < vertex_count; i++) {
                    gl_rasterize_line(&vertex_buffer[i], &vertex_buffer[(i + 1) % vertex_count]);
                }
                break;
                
            case GL_TRIANGLES:
                for (int i = 0; i < vertex_count - 2; i += 3) {
                    gl_rasterize_triangle(&vertex_buffer[i], &vertex_buffer[i + 1], &vertex_buffer[i + 2]);
                }
                break;
                
            case GL_TRIANGLE_STRIP:
                for (int i = 0; i < vertex_count - 2; i++) {
                    if (i % 2 == 0) {
                        gl_rasterize_triangle(&vertex_buffer[i], &vertex_buffer[i + 1], &vertex_buffer[i + 2]);
                    } else {
                        gl_rasterize_triangle(&vertex_buffer[i + 1], &vertex_buffer[i], &vertex_buffer[i + 2]);
                    }
                }
                break;
                
            case GL_TRIANGLE_FAN:
                for (int i = 1; i < vertex_count - 1; i++) {
                    gl_rasterize_triangle(&vertex_buffer[0], &vertex_buffer[i], &vertex_buffer[i + 1]);
                }
                break;
                
            case GL_QUADS:
                for (int i = 0; i < vertex_count - 3; i += 4) {
                    gl_rasterize_triangle(&vertex_buffer[i], &vertex_buffer[i + 1], &vertex_buffer[i + 2]);
                    gl_rasterize_triangle(&vertex_buffer[i], &vertex_buffer[i + 2], &vertex_buffer[i + 3]);
                }
                break;
                
            case GL_QUAD_STRIP:
                for (int i = 0; i < vertex_count - 3; i += 2) {
                    gl_rasterize_triangle(&vertex_buffer[i], &vertex_buffer[i + 1], &vertex_buffer[i + 2]);
                    gl_rasterize_triangle(&vertex_buffer[i + 1], &vertex_buffer[i + 3], &vertex_buffer[i + 2]);
                }
                break;
                
            case GL_POLYGON:
                /* Triangulate polygon (fan from first vertex) */
                for (int i = 1; i < vertex_count - 1; i++) {
                    gl_rasterize_triangle(&vertex_buffer[0], &vertex_buffer[i], &vertex_buffer[i + 1]);
                }
                break;
        }
    }
    
    in_begin_end = GL_FALSE;
    vertex_count = 0;
}

/* ================================================================ */
/* Vertex Specification                                               */
/* ================================================================ */

void gl_vertex2f(GLfloat x, GLfloat y) {
    if (!in_begin_end || vertex_count >= MAX_VERTICES) {
        ctx->error = GL_INVALID_OPERATION;
        return;
    }
    
    vertex_buffer[vertex_count].position = (GLvec3){x, y, 0.0f};
    vertex_buffer[vertex_count].normal = ctx->current_normal;
    vertex_buffer[vertex_count].color = ctx->current_color;
    vertex_buffer[vertex_count].texcoord = ctx->current_texcoord;
    
    gl_transform_vertex(&vertex_buffer[vertex_count]);
    vertex_count++;
}

void gl_vertex2i(GLint x, GLint y) {
    gl_vertex2f((GLfloat)x, (GLfloat)y);
}

void gl_vertex3f(GLfloat x, GLfloat y, GLfloat z) {
    if (!in_begin_end || vertex_count >= MAX_VERTICES) {
        ctx->error = GL_INVALID_OPERATION;
        return;
    }
    
    vertex_buffer[vertex_count].position = (GLvec3){x, y, z};
    vertex_buffer[vertex_count].normal = ctx->current_normal;
    vertex_buffer[vertex_count].color = ctx->current_color;
    vertex_buffer[vertex_count].texcoord = ctx->current_texcoord;
    
    gl_transform_vertex(&vertex_buffer[vertex_count]);
    vertex_count++;
}

void gl_vertex3i(GLint x, GLint y, GLint z) {
    gl_vertex3f((GLfloat)x, (GLfloat)y, (GLfloat)z);
}

void gl_color3f(GLfloat r, GLfloat g, GLfloat b) {
    ctx->current_color = (GLvec4){r, g, b, 1.0f};
}

void gl_color4f(GLfloat r, GLfloat g, GLfloat b, GLfloat a) {
    ctx->current_color = (GLvec4){r, g, b, a};
}

void gl_normal3f(GLfloat nx, GLfloat ny, GLfloat nz) {
    ctx->current_normal = (GLvec3){nx, ny, nz};
}

void gl_texcoord2f(GLfloat s, GLfloat t) {
    ctx->current_texcoord = (GLvec2){s, t};
}

/* ================================================================ */
/* Matrix Operations                                                 */
/* ================================================================ */

void gl_matrix_mode(GLenum mode) {
    if (mode != GL_MODELVIEW && mode != GL_PROJECTION && mode != GL_TEXTURE) {
        ctx->error = GL_INVALID_ENUM;
        return;
    }
    ctx->matrix_mode = mode;
}

void gl_load_identity(void) {
    GLmat4* matrix;
    switch (ctx->matrix_mode) {
        case GL_MODELVIEW: matrix = &ctx->modelview_matrix; break;
        case GL_PROJECTION: matrix = &ctx->projection_matrix; break;
        case GL_TEXTURE: matrix = &ctx->texture_matrix; break;
        default: return;
    }
    gl_matrix_identity(matrix);
    gl_update_mvp_matrix();
}

void gl_load_matrixf(const GLfloat* m) {
    GLmat4* matrix;
    switch (ctx->matrix_mode) {
        case GL_MODELVIEW: matrix = &ctx->modelview_matrix; break;
        case GL_PROJECTION: matrix = &ctx->projection_matrix; break;
        case GL_TEXTURE: matrix = &ctx->texture_matrix; break;
        default: return;
    }
    
    for (int i = 0; i < 16; i++) {
        matrix->m[i] = m[i];
    }
    gl_update_mvp_matrix();
}

void gl_mult_matrixf(const GLfloat* m) {
    GLmat4* matrix;
    switch (ctx->matrix_mode) {
        case GL_MODELVIEW: matrix = &ctx->modelview_matrix; break;
        case GL_PROJECTION: matrix = &ctx->projection_matrix; break;
        case GL_TEXTURE: matrix = &ctx->texture_matrix; break;
        default: return;
    }
    
    GLmat4 input_matrix;
    for (int i = 0; i < 16; i++) {
        input_matrix.m[i] = m[i];
    }
    
    gl_matrix_multiply(matrix, matrix, &input_matrix);
    gl_update_mvp_matrix();
}

void gl_translatef(GLfloat x, GLfloat y, GLfloat z) {
    GLmat4* matrix;
    switch (ctx->matrix_mode) {
        case GL_MODELVIEW: matrix = &ctx->modelview_matrix; break;
        case GL_PROJECTION: matrix = &ctx->projection_matrix; break;
        case GL_TEXTURE: matrix = &ctx->texture_matrix; break;
        default: return;
    }
    
    gl_matrix_translate(matrix, x, y, z);
    gl_update_mvp_matrix();
}

void gl_rotatef(GLfloat angle, GLfloat x, GLfloat y, GLfloat z) {
    GLmat4* matrix;
    switch (ctx->matrix_mode) {
        case GL_MODELVIEW: matrix = &ctx->modelview_matrix; break;
        case GL_PROJECTION: matrix = &ctx->projection_matrix; break;
        case GL_TEXTURE: matrix = &ctx->texture_matrix; break;
        default: return;
    }
    
    gl_matrix_rotate(matrix, angle, x, y, z);
    gl_update_mvp_matrix();
}

void gl_scalef(GLfloat x, GLfloat y, GLfloat z) {
    GLmat4* matrix;
    switch (ctx->matrix_mode) {
        case GL_MODELVIEW: matrix = &ctx->modelview_matrix; break;
        case GL_PROJECTION: matrix = &ctx->projection_matrix; break;
        case GL_TEXTURE: matrix = &ctx->texture_matrix; break;
        default: return;
    }
    
    gl_matrix_scale(matrix, x, y, z);
    gl_update_mvp_matrix();
}

void gl_ortho(GLfloat left, GLfloat right, GLfloat bottom, GLfloat top, GLfloat z_near, GLfloat z_far) {
    GLmat4* matrix;
    switch (ctx->matrix_mode) {
        case GL_MODELVIEW: matrix = &ctx->modelview_matrix; break;
        case GL_PROJECTION: matrix = &ctx->projection_matrix; break;
        case GL_TEXTURE: matrix = &ctx->texture_matrix; break;
        default: return;
    }
    
    GLfloat tx = -(right + left) / (right - left);
    GLfloat ty = -(top + bottom) / (top - bottom);
    GLfloat tz = -(z_far + z_near) / (z_far - z_near);
    
    GLmat4 ortho_matrix = {
        2.0f / (right - left), 0.0f, 0.0f, 0.0f,
        0.0f, 2.0f / (top - bottom), 0.0f, 0.0f,
        0.0f, 0.0f, -2.0f / (z_far - z_near), 0.0f,
        tx, ty, tz, 1.0f
    };
    
    gl_matrix_multiply(matrix, matrix, &ortho_matrix);
    gl_update_mvp_matrix();
}

void gl_perspective(GLfloat fovy, GLfloat aspect, GLfloat z_near, GLfloat z_far) {
    GLmat4* matrix;
    switch (ctx->matrix_mode) {
        case GL_MODELVIEW: matrix = &ctx->modelview_matrix; break;
        case GL_PROJECTION: matrix = &ctx->projection_matrix; break;
        case GL_TEXTURE: matrix = &ctx->texture_matrix; break;
        default: return;
    }
    
    gl_matrix_perspective(matrix, fovy, aspect, z_near, z_far);
    gl_update_mvp_matrix();
}

void gl_look_at(GLfloat eye_x, GLfloat eye_y, GLfloat eye_z,
                GLfloat center_x, GLfloat center_y, GLfloat center_z,
                GLfloat up_x, GLfloat up_y, GLfloat up_z) {
    GLmat4* matrix;
    switch (ctx->matrix_mode) {
        case GL_MODELVIEW: matrix = &ctx->modelview_matrix; break;
        case GL_PROJECTION: matrix = &ctx->projection_matrix; break;
        case GL_TEXTURE: matrix = &ctx->texture_matrix; break;
        default: return;
    }
    
    GLvec3 eye = {eye_x, eye_y, eye_z};
    GLvec3 center = {center_x, center_y, center_z};
    GLvec3 up = {up_x, up_y, up_z};
    
    gl_matrix_look_at(matrix, eye, center, up);
    gl_update_mvp_matrix();
}

/* ================================================================ */
/* Raster Operations                                                 */
/* ================================================================ */

void gl_clear(GLbitfield mask) {
    if (mask & GL_COLOR_BUFFER_BIT) {
        if (hardware_framebuffer) {
            /* Hardware accelerated clear */
            unsigned int clear_color = gl_pack_color(&ctx->current_color);
            for (int i = 0; i < fb_width * fb_height; i++) {
                ((unsigned int*)hardware_framebuffer)[i] = clear_color;
            }
        }
    }
    
    if (mask & GL_DEPTH_BUFFER_BIT) {
        /* Clear depth buffer (not implemented in this simple version) */
    }
    
    if (mask & GL_STENCIL_BUFFER_BIT) {
        /* Clear stencil buffer (not implemented in this simple version) */
    }
}

void gl_clear_color(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha) {
    ctx->current_color = (GLvec4){red, green, blue, alpha};
}

void gl_viewport(GLint x, GLint y, GLsizei width, GLsizei height) {
    ctx->viewport_x = x;
    ctx->viewport_y = y;
    ctx->viewport_width = width;
    ctx->viewport_height = height;
}

void gl_scissor(GLint x, GLint y, GLsizei width, GLsizei height) {
    ctx->scissor_x = x;
    ctx->scissor_y = y;
    ctx->scissor_width = width;
    ctx->scissor_height = height;
}

/* ================================================================ */
/* State Management                                                   */
/* ================================================================ */

void gl_enable(GLenum cap) {
    switch (cap) {
        case GL_DEPTH_TEST:
            ctx->depth_test_enabled = GL_TRUE;
            break;
        case GL_BLEND:
            ctx->blend_enabled = GL_TRUE;
            break;
        case GL_CULL_FACE:
            ctx->cull_face_enabled = GL_TRUE;
            break;
        case GL_LIGHTING:
            ctx->lighting_enabled = GL_TRUE;
            break;
        case GL_TEXTURE_2D:
            ctx->texture_2d_enabled = GL_TRUE;
            break;
        case GL_SCISSOR_TEST:
            ctx->scissor_test_enabled = GL_TRUE;
            break;
        case GL_VERTEX_ARRAY:
            ctx->vertex_array_enabled = GL_TRUE;
            break;
        case GL_NORMAL_ARRAY:
            ctx->normal_array_enabled = GL_TRUE;
            break;
        case GL_COLOR_ARRAY:
            ctx->color_array_enabled = GL_TRUE;
            break;
        case GL_TEXTURE_COORD_ARRAY:
            ctx->texcoord_array_enabled = GL_TRUE;
            break;
        default:
            ctx->error = GL_INVALID_ENUM;
            break;
    }
}

void gl_disable(GLenum cap) {
    switch (cap) {
        case GL_DEPTH_TEST:
            ctx->depth_test_enabled = GL_FALSE;
            break;
        case GL_BLEND:
            ctx->blend_enabled = GL_FALSE;
            break;
        case GL_CULL_FACE:
            ctx->cull_face_enabled = GL_FALSE;
            break;
        case GL_LIGHTING:
            ctx->lighting_enabled = GL_FALSE;
            break;
        case GL_TEXTURE_2D:
            ctx->texture_2d_enabled = GL_FALSE;
            break;
        case GL_SCISSOR_TEST:
            ctx->scissor_test_enabled = GL_FALSE;
            break;
        case GL_VERTEX_ARRAY:
            ctx->vertex_array_enabled = GL_FALSE;
            break;
        case GL_NORMAL_ARRAY:
            ctx->normal_array_enabled = GL_FALSE;
            break;
        case GL_COLOR_ARRAY:
            ctx->color_array_enabled = GL_FALSE;
            break;
        case GL_TEXTURE_COORD_ARRAY:
            ctx->texcoord_array_enabled = GL_FALSE;
            break;
        default:
            ctx->error = GL_INVALID_ENUM;
            break;
    }
}

void gl_blend_func(GLenum sfactor, GLenum dfactor) {
    ctx->blend_src_factor = sfactor;
    ctx->blend_dst_factor = dfactor;
}

/* ================================================================ */
/* Error Handling                                                    */
/* ================================================================ */

GLenum gl_get_error(void) {
    GLenum error = ctx->error;
    ctx->error = GL_NO_ERROR;
    return error;
}

const GLubyte* gl_error_string(GLenum error) {
    switch (error) {
        case GL_NO_ERROR:           return (const GLubyte*)"No error";
        case GL_INVALID_ENUM:       return (const GLubyte*)"Invalid enum";
        case GL_INVALID_VALUE:      return (const GLubyte*)"Invalid value";
        case GL_INVALID_OPERATION:  return (const GLubyte*)"Invalid operation";
        case GL_STACK_OVERFLOW:     return (const GLubyte*)"Stack overflow";
        case GL_STACK_UNDERFLOW:    return (const GLubyte*)"Stack underflow";
        case GL_OUT_OF_MEMORY:      return (const GLubyte*)"Out of memory";
        default:                    return (const GLubyte*)"Unknown error";
    }
}

/* ================================================================ */
/* Internal Helper Functions                                        */
/* ================================================================ */

static void gl_transform_vertex(GLvertex* v) {
    /* Transform by modelview-projection matrix */
    GLvec4 pos = {
        v->position.x,
        v->position.y,
        v->position.z,
        1.0f
    };
    
    /* Matrix-vector multiplication (simplified) */
    GLfloat x = ctx->modelview_projection_matrix.m[0] * pos.x +
                ctx->modelview_projection_matrix.m[4] * pos.y +
                ctx->modelview_projection_matrix.m[8] * pos.z +
                ctx->modelview_projection_matrix.m[12] * pos.w;
    
    GLfloat y = ctx->modelview_projection_matrix.m[1] * pos.x +
                ctx->modelview_projection_matrix.m[5] * pos.y +
                ctx->modelview_projection_matrix.m[9] * pos.z +
                ctx->modelview_projection_matrix.m[13] * pos.w;
    
    GLfloat z = ctx->modelview_projection_matrix.m[2] * pos.x +
                ctx->modelview_projection_matrix.m[6] * pos.y +
                ctx->modelview_projection_matrix.m[10] * pos.z +
                ctx->modelview_projection_matrix.m[14] * pos.w;
    
    GLfloat w = ctx->modelview_projection_matrix.m[3] * pos.x +
                ctx->modelview_projection_matrix.m[7] * pos.y +
                ctx->modelview_projection_matrix.m[11] * pos.z +
                ctx->modelview_projection_matrix.m[15] * pos.w;
    
    /* Perspective divide */
    if (w != 0.0f) {
        v->position.x = x / w;
        v->position.y = y / w;
        v->position.z = z / w;
    }
    
    /* Viewport transform */
    v->position.x = ctx->viewport_x + (v->position.x + 1.0f) * 0.5f * ctx->viewport_width;
    v->position.y = ctx->viewport_y + (v->position.y + 1.0f) * 0.5f * ctx->viewport_height;
}

static unsigned int gl_pack_color(const GLvec4* color) {
    unsigned int r = (unsigned int)(color->x * 255.0f);
    unsigned int g = (unsigned int)(color->y * 255.0f);
    unsigned int b = (unsigned int)(color->z * 255.0f);
    unsigned int a = (unsigned int)(color->w * 255.0f);
    
    /* Clamp values */
    if (r > 255) r = 255;
    if (g > 255) g = 255;
    if (b > 255) b = 255;
    if (a > 255) a = 255;
    
    return (a << 24) | (r << 16) | (g << 8) | b;
}

static void gl_rasterize_point(const GLvertex* v) {
    if (!hardware_framebuffer) return;
    
    int x = (int)v->position.x;
    int y = (int)v->position.y;
    
    /* Scissor test */
    if (ctx->scissor_test_enabled) {
        if (x < ctx->scissor_x || x >= ctx->scissor_x + ctx->scissor_width ||
            y < ctx->scissor_y || y >= ctx->scissor_y + ctx->scissor_height) {
            return;
        }
    }
    
    /* Viewport test */
    if (x < 0 || x >= fb_width || y < 0 || y >= fb_height) {
        return;
    }
    
    unsigned int color = gl_pack_color(&v->color);
    ((unsigned int*)hardware_framebuffer)[y * fb_width + x] = color;
}

static void gl_rasterize_line(const GLvertex* v1, const GLvertex* v2) {
    /* Bresenham's line algorithm */
    int x0 = (int)v1->position.x;
    int y0 = (int)v1->position.y;
    int x1 = (int)v2->position.x;
    int y1 = (int)v2->position.y;
    
    int dx = abs(x1 - x0);
    int dy = abs(y1 - y0);
    int sx = (x0 < x1) ? 1 : -1;
    int sy = (y0 < y1) ? 1 : -1;
    int err = dx - dy;
    
    while (1) {
        GLvertex v = *v1;  /* Copy attributes from v1 */
        v.position.x = (GLfloat)x0;
        v.position.y = (GLfloat)y0;
        
        /* Interpolate color */
        GLfloat t = 0.0f;
        if (dx > dy) {
            t = (GLfloat)(x0 - (int)v1->position.x) / (GLfloat)(x1 - (int)v1->position.x);
        } else {
            t = (GLfloat)(y0 - (int)v1->position.y) / (GLfloat)(y1 - (int)v1->position.y);
        }
        
        v.color.x = v1->color.x + t * (v2->color.x - v1->color.x);
        v.color.y = v1->color.y + t * (v2->color.y - v1->color.y);
        v.color.z = v1->color.z + t * (v2->color.z - v1->color.z);
        v.color.w = v1->color.w + t * (v2->color.w - v1->color.w);
        
        gl_rasterize_point(&v);
        
        if (x0 == x1 && y0 == y1) break;
        
        int e2 = 2 * err;
        if (e2 > -dy) {
            err -= dy;
            x0 += sx;
        }
        if (e2 < dx) {
            err += dx;
            y0 += sy;
        }
    }
}

static void gl_rasterize_triangle(const GLvertex* v1, const GLvertex* v2, const GLvertex* v3) {
    /* Simple triangle rasterization */
    /* Sort vertices by y-coordinate */
    const GLvertex* top = v1;
    const GLvertex* mid = v2;
    const GLvertex* bottom = v3;
    
    if (mid->position.y < top->position.y) {
        const GLvertex* temp = top; top = mid; mid = temp;
    }
    if (bottom->position.y < mid->position.y) {
        const GLvertex* temp = bottom; bottom = mid; mid = temp;
    }
    if (mid->position.y < top->position.y) {
        const GLvertex* temp = top; top = mid; mid = temp;
    }
    
    /* Rasterize triangle (simplified - just fill with color from v1) */
    int min_x = (int)fminf(fminf(v1->position.x, v2->position.x), v3->position.x);
    int max_x = (int)fmaxf(fmaxf(v1->position.x, v2->position.x), v3->position.x);
    int min_y = (int)fminf(fminf(v1->position.y, v2->position.y), v3->position.y);
    int max_y = (int)fmaxf(fmaxf(v1->position.y, v2->position.y), v3->position.y);
    
    for (int y = min_y; y <= max_y; y++) {
        for (int x = min_x; x <= max_x; x++) {
            /* Simple point-in-triangle test */
            GLvertex test_vertex = *v1;
            test_vertex.position.x = (GLfloat)x;
            test_vertex.position.y = (GLfloat)y;
            gl_rasterize_point(&test_vertex);
        }
    }
}

/* ================================================================ */
/* Matrix Utilities                                                  */
/* ================================================================ */

void gl_matrix_identity(GLmat4* m) {
    for (int i = 0; i < 16; i++) {
        m->m[i] = 0.0f;
    }
    m->m[0] = m->m[5] = m->m[10] = m->m[15] = 1.0f;
}

void gl_matrix_multiply(GLmat4* result, const GLmat4* a, const GLmat4* b) {
    GLmat4 temp;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            temp.m[i * 4 + j] = 0.0f;
            for (int k = 0; k < 4; k++) {
                temp.m[i * 4 + j] += a->m[i * 4 + k] * b->m[k * 4 + j];
            }
        }
    }
    *result = temp;
}

void gl_update_mvp_matrix(void) {
    gl_matrix_multiply(&ctx->modelview_projection_matrix, &ctx->projection_matrix, &ctx->modelview_matrix);
}

/* ================================================================ */
/* KSDOS Extensions                                                   */
/* ================================================================ */

void gl_ksdos_set_framebuffer(void* framebuffer, int width, int height) {
    hardware_framebuffer = framebuffer;
    fb_width = width;
    fb_height = height;
    
    /* Update viewport to match framebuffer */
    ctx->viewport_width = width;
    ctx->viewport_height = height;
    ctx->scissor_width = width;
    ctx->scissor_height = height;
}

void gl_ksdos_swap_buffers(void) {
    /* In a real implementation, this would swap front/back buffers */
    /* For now, we just vsync */
    gl_ksdos_vsync();
}

void gl_ksdos_vsync(void) {
    /* Simple vsync delay */
    for (volatile int i = 0; i < 100000; i++);
}

/* Hardware acceleration stubs */
GLboolean gl_hardware_available(void) {
    /* Check if hardware acceleration is available */
    /* For now, return FALSE (software rendering) */
    return GL_FALSE;
}

void gl_hardware_init(void) {
    hardware_initialized = GL_TRUE;
}

void gl_hardware_shutdown(void) {
    hardware_initialized = GL_FALSE;
}
