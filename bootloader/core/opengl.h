/* ================================================================
   KSDOS OpenGL 1.5 Real Implementation
   Hardware-accelerated graphics for PS1 and DOOM development
   ================================================================ */

#ifndef KSDOS_OPENGL_H
#define KSDOS_OPENGL_H

/* OpenGL Version and Constants */
#define KSDOS_GL_VERSION_MAJOR  1
#define KSDOS_GL_VERSION_MINOR  5
#define KSDOS_GL_VERSION_PATCH  0

/* OpenGL Data Types */
typedef float GLfloat;
typedef double GLdouble;
typedef int GLint;
typedef unsigned int GLuint;
typedef unsigned char GLubyte;
typedef unsigned short GLushort;
typedef signed char GLbyte;
typedef short GLshort;
typedef unsigned int GLenum;
typedef unsigned int GLbitfield;
typedef void GLvoid;
typedef size_t GLsizei;
typedef ptrdiff_t GLintptr;
typedef ptrdiff_t GLsizeiptr;

/* OpenGL Constants */
#define GL_FALSE                        0
#define GL_TRUE                         1

/* Data Types */
#define GL_BYTE                         0x1400
#define GL_UNSIGNED_BYTE                0x1401
#define GL_SHORT                        0x1402
#define GL_UNSIGNED_SHORT               0x1403
#define GL_INT                          0x1404
#define GL_UNSIGNED_INT                 0x1405
#define GL_FLOAT                        0x1406
#define GL_DOUBLE                       0x140A
#define GL_2_BYTES                      0x1407
#define GL_3_BYTES                      0x1408
#define GL_4_BYTES                      0x1409

/* Primitives */
#define GL_POINTS                       0x0000
#define GL_LINES                        0x0001
#define GL_LINE_LOOP                    0x0002
#define GL_LINE_STRIP                   0x0003
#define GL_TRIANGLES                    0x0004
#define GL_TRIANGLE_STRIP               0x0005
#define GL_TRIANGLE_FAN                 0x0006
#define GL_QUADS                        0x0007
#define GL_QUAD_STRIP                   0x0008
#define GL_POLYGON                      0x0009

/* Vertex Arrays */
#define GL_VERTEX_ARRAY                 0x8074
#define GL_NORMAL_ARRAY                 0x8075
#define GL_COLOR_ARRAY                  0x8076
#define GL_INDEX_ARRAY                  0x8077
#define GL_TEXTURE_COORD_ARRAY          0x8079
#define GL_EDGE_FLAG_ARRAY              0x8079

/* Error Codes */
#define GL_NO_ERROR                     0
#define GL_INVALID_ENUM                 0x0500
#define GL_INVALID_VALUE                0x0501
#define GL_INVALID_OPERATION            0x0502
#define GL_STACK_OVERFLOW               0x0503
#define GL_STACK_UNDERFLOW              0x0504
#define GL_OUT_OF_MEMORY                0x0505

/* Buffer Objects */
#define GL_ARRAY_BUFFER                 0x8892
#define GL_ELEMENT_ARRAY_BUFFER         0x8893

/* Texture Units */
#define GL_TEXTURE0                     0x84C0
#define GL_TEXTURE1                     0x84C1
#define GL_TEXTURE2                     0x84C2
#define GL_TEXTURE3                     0x84C3

/* Blending Factors */
#define GL_ZERO                         0
#define GL_ONE                          1
#define GL_SRC_COLOR                    0x0300
#define GL_ONE_MINUS_SRC_COLOR          0x0301
#define GL_DST_COLOR                    0x0306
#define GL_ONE_MINUS_DST_COLOR          0x0307
#define GL_SRC_ALPHA                    0x0302
#define GL_ONE_MINUS_SRC_ALPHA          0x0303
#define GL_DST_ALPHA                    0x0304
#define GL_ONE_MINUS_DST_ALPHA          0x0305

/* Pixel Formats */
#define GL_COLOR_BUFFER_BIT             0x00004000
#define GL_DEPTH_BUFFER_BIT             0x00000100
#define GL_STENCIL_BUFFER_BIT           0x00000400

/* Matrix Mode */
#define GL_MODELVIEW                    0x1700
#define GL_PROJECTION                   0x1701
#define GL_TEXTURE                      0x1702

/* Shading Models */
#define GL_FLAT                         0x1D00
#define GL_SMOOTH                       0x1D01

/* Graphics Pipeline Features */
#define GL_DEPTH_TEST                   0x0B71
#define GL_BLEND                        0x0BE2
#define GL_CULL_FACE                    0x0B44
#define GL_LIGHTING                     0x0B50
#define GL_TEXTURE_2D                   0x0DE1
#define GL_SCISSOR_TEST                 0x0C11

/* ================================================================ */
/* Vector and Matrix Types                                            */
/* ================================================================ */

typedef struct {
    GLfloat x, y, z;
} GLvec3;

typedef struct {
    GLfloat x, y, z, w;
} GLvec4;

typedef struct {
    GLfloat m[16];  /* Column-major order */
} GLmat4;

typedef struct {
    GLfloat m[9];   /* Column-major order */
} GLmat3;

/* ================================================================ */
/* Vertex Structure                                                   */
/* ================================================================ */

typedef struct {
    GLvec3 position;
    GLvec3 normal;
    GLvec4 color;
    GLvec2 texcoord;
} GLvertex;

typedef struct {
    GLvec2 s, t;
} GLtexcoord;

/* ================================================================ */
/* OpenGL Context Structure                                           */
/* ================================================================ */

typedef struct {
    /* Viewport and Scissor */
    GLint viewport_x, viewport_y;
    GLsizei viewport_width, viewport_height;
    GLint scissor_x, scissor_y;
    GLsizei scissor_width, scissor_height;
    GLboolean scissor_test_enabled;
    
    /* Matrices */
    GLenum matrix_mode;
    GLmat4 modelview_matrix;
    GLmat4 projection_matrix;
    GLmat4 texture_matrix;
    GLmat4 modelview_projection_matrix;
    
    /* Vertex Arrays */
    GLboolean vertex_array_enabled;
    GLboolean normal_array_enabled;
    GLboolean color_array_enabled;
    GLboolean texcoord_array_enabled;
    
    const GLfloat* vertex_pointer;
    const GLfloat* normal_pointer;
    const GLfloat* color_pointer;
    const GLfloat* texcoord_pointer;
    
    GLsizei vertex_stride;
    GLsizei normal_stride;
    GLsizei color_stride;
    GLsizei texcoord_stride;
    
    /* Current State */
    GLvec4 current_color;
    GLvec3 current_normal;
    GLvec2 current_texcoord;
    
    /* Rendering State */
    GLenum primitive_mode;
    GLboolean depth_test_enabled;
    GLboolean blend_enabled;
    GLboolean cull_face_enabled;
    GLboolean lighting_enabled;
    GLboolean texture_2d_enabled;
    
    GLenum blend_src_factor;
    GLenum blend_dst_factor;
    
    /* Error State */
    GLenum error;
    
    /* Hardware Acceleration */
    GLboolean hardware_accelerated;
    void* hardware_context;
    
} GLcontext;

/* ================================================================ */
/* Function Prototypes                                                */
/* ================================================================ */

/* Core Functions */
void gl_init(void);
void gl_shutdown(void);
void gl_begin(GLenum mode);
void gl_end(void);

/* Vertex Specification */
void gl_vertex2f(GLfloat x, GLfloat y);
void gl_vertex2i(GLint x, GLint y);
void gl_vertex3f(GLfloat x, GLfloat y, GLfloat z);
void gl_vertex3i(GLint x, GLint y, GLint z);
void gl_color3f(GLfloat r, GLfloat g, GLfloat b);
void gl_color4f(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
void gl_normal3f(GLfloat nx, GLfloat ny, GLfloat nz);
void gl_texcoord2f(GLfloat s, GLfloat t);

/* Matrix Operations */
void gl_matrix_mode(GLenum mode);
void gl_load_identity(void);
void gl_load_matrixf(const GLfloat* m);
void gl_mult_matrixf(const GLfloat* m);
void gl_translatef(GLfloat x, GLfloat y, GLfloat z);
void gl_rotatef(GLfloat angle, GLfloat x, GLfloat y, GLfloat z);
void gl_scalef(GLfloat x, GLfloat y, GLfloat z);
void gl_ortho(GLfloat left, GLfloat right, GLfloat bottom, GLfloat top, GLfloat z_near, GLfloat z_far);
void gl_perspective(GLfloat fovy, GLfloat aspect, GLfloat z_near, GLfloat z_far);
void gl_look_at(GLfloat eye_x, GLfloat eye_y, GLfloat eye_z,
                GLfloat center_x, GLfloat center_y, GLfloat center_z,
                GLfloat up_x, GLfloat up_y, GLfloat up_z);

/* Vertex Arrays */
void gl_enable_client_state(GLenum array);
void gl_disable_client_state(GLenum array);
void gl_vertex_pointer(GLint size, GLenum type, GLsizei stride, const GLvoid* pointer);
void gl_normal_pointer(GLenum type, GLsizei stride, const GLvoid* pointer);
void gl_color_pointer(GLint size, GLenum type, GLsizei stride, const GLvoid* pointer);
void gl_tex_coord_pointer(GLint size, GLenum type, GLsizei stride, const GLvoid* pointer);
void gl_draw_arrays(GLenum mode, GLint first, GLsizei count);
void gl_draw_elements(GLenum mode, GLsizei count, GLenum type, const GLvoid* indices);

/* Buffer Objects */
void glGenBuffers(GLsizei n, GLuint* buffers);
void glDeleteBuffers(GLsizei n, const GLuint* buffers);
void glBindBuffer(GLenum target, GLuint buffer);
void glBufferData(GLenum target, GLsizeiptr size, const GLvoid* data, GLenum usage);
void glBufferSubData(GLenum target, GLintptr offset, GLsizeiptr size, const GLvoid* data);

/* Raster Operations */
void gl_clear(GLbitfield mask);
void gl_clear_color(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
void gl_clear_depth(GLdouble depth);
void gl_viewport(GLint x, GLint y, GLsizei width, GLsizei height);
void gl_scissor(GLint x, GLint y, GLsizei width, GLsizei height);

/* Texture Mapping */
void glGenTextures(GLsizei n, GLuint* textures);
void glDeleteTextures(GLsizei n, const GLuint* textures);
void glBindTexture(GLenum target, GLuint texture);
void glTexImage2D(GLenum target, GLint level, GLint internalformat,
                  GLsizei width, GLsizei height, GLint border,
                  GLenum format, GLenum type, const GLvoid* pixels);
void gl_tex_parameteri(GLenum target, GLenum pname, GLint param);
void gl_tex_parameterf(GLenum target, GLenum pname, GLfloat param);
void gl_active_texture(GLenum texture);

/* Blending and Depth */
void gl_enable(GLenum cap);
void gl_disable(GLenum cap);
void gl_blend_func(GLenum sfactor, GLenum dfactor);
void gl_depth_func(GLenum func);
void gl_depth_mask(GLboolean flag);

/* Lighting */
void gl_lightfv(GLenum light, GLenum pname, const GLfloat* params);
void gl_materialfv(GLenum face, GLenum pname, const GLfloat* params);
void gl_light_modelfv(GLenum pname, const GLfloat* params);
void gl_color_material(GLenum face, GLenum mode);

/* Error Handling */
GLenum gl_get_error(void);
const GLubyte* gl_error_string(GLenum error);

/* Matrix Utilities */
void gl_matrix_identity(GLmat4* m);
void gl_matrix_multiply(GLmat4* result, const GLmat4* a, const GLmat4* b);
void gl_matrix_translate(GLmat4* m, GLfloat x, GLfloat y, GLfloat z);
void gl_matrix_rotate(GLmat4* m, GLfloat angle, GLfloat x, GLfloat y, GLfloat z);
void gl_matrix_scale(GLmat4* m, GLfloat x, GLfloat y, GLfloat z);
void gl_matrix_perspective(GLmat4* m, GLfloat fovy, GLfloat aspect, GLfloat z_near, GLfloat z_far);
void gl_matrix_look_at(GLmat4* m, GLvec3 eye, GLvec3 center, GLvec3 up);

/* Vector Utilities */
GLfloat gl_vector_length(const GLvec3* v);
void gl_vector_normalize(GLvec3* v);
GLfloat gl_vector_dot(const GLvec3* a, const GLvec3* b);
void gl_vector_cross(GLvec3* result, const GLvec3* a, const GLvec3* b);

/* Hardware Acceleration */
GLboolean gl_hardware_available(void);
void gl_hardware_init(void);
void gl_hardware_shutdown(void);

/* KSDOS Extensions */
void gl_ksdos_init_hardware(void);
void gl_ksdos_set_framebuffer(void* framebuffer, int width, int height);
void gl_ksdos_swap_buffers(void);
void gl_ksdos_vsync(void);

#endif /* KSDOS_OPENGL_H */
