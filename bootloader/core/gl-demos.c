/* ================================================================
   KSDOS OpenGL Real Implementation Demo Suite
   Demonstrates hardware-accelerated OpenGL 1.5 features
   ================================================================ */

#include "opengl.h"
#include "gl-context.c"
#include "gl-hardware.c"
#include <math.h>

/* External VBE functions */
extern void vbe_init(void);
extern void vbe_shutdown(void);
extern void delay(unsigned int count);
extern int kbd_key_available(void);
extern unsigned char kbd_getchar(void);
extern void inb(unsigned short port);

/* Demo timing */
#define DEMO_FRAMES 300
#define DEMO_DELAY 250000

/* ================================================================ */
/* Real OpenGL Cube Demo                                            */
/* ================================================================ */

void gl_real_demo_cube(void) {
    vbe_init();
    
    /* Create OpenGL context */
    GLuint context = gl_create_context((void*)0xE0000000, 640, 480, 32);
    if (!context) {
        return;  /* Failed to create context */
    }
    
    gl_make_current(context);
    
    /* Setup OpenGL state */
    gl_clear_color(0.04f, 0.04f, 0.12f, 1.0f);  /* Dark blue background */
    gl_enable(GL_DEPTH_TEST);
    gl_matrix_mode(GL_PROJECTION);
    gl_load_identity();
    gl_perspective(45.0f, 640.0f / 480.0f, 0.1f, 100.0f);
    gl_matrix_mode(GL_MODELVIEW);
    gl_load_identity();
    
    /* Check for hardware acceleration */
    GLboolean hw_accel = GL_FALSE;
    gl_get_context_info(context, NULL, NULL, NULL, &hw_accel);
    
    /* Animation loop */
    for (int frame = 0; frame < DEMO_FRAMES; frame++) {
        gl_context_begin_frame(context);
        
        /* Clear buffers */
        gl_clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        /* Setup view */
        gl_load_identity();
        gl_translatef(0.0f, 0.0f, -5.0f);
        gl_rotatef(frame * 2.0f, 1.0f, 0.0f, 0.0f);
        gl_rotatef(frame * 3.0f, 0.0f, 1.0f, 0.0f);
        gl_rotatef(frame * 1.0f, 0.0f, 0.0f, 1.0f);
        
        /* Draw cube faces */
        gl_begin(GL_QUADS);
        
        /* Front face - red */
        gl_color3f(0.86f, 0.20f, 0.20f);
        gl_vertex3f(-1.0f, -1.0f,  1.0f);
        gl_vertex3f( 1.0f, -1.0f,  1.0f);
        gl_vertex3f( 1.0f,  1.0f,  1.0f);
        gl_vertex3f(-1.0f,  1.0f,  1.0f);
        
        /* Back face - green */
        gl_color3f(0.20f, 0.86f, 0.20f);
        gl_vertex3f(-1.0f, -1.0f, -1.0f);
        gl_vertex3f(-1.0f,  1.0f, -1.0f);
        gl_vertex3f( 1.0f,  1.0f, -1.0f);
        gl_vertex3f( 1.0f, -1.0f, -1.0f);
        
        /* Top face - blue */
        gl_color3f(0.20f, 0.39f, 0.86f);
        gl_vertex3f(-1.0f,  1.0f, -1.0f);
        gl_vertex3f(-1.0f,  1.0f,  1.0f);
        gl_vertex3f( 1.0f,  1.0f,  1.0f);
        gl_vertex3f( 1.0f,  1.0f, -1.0f);
        
        /* Bottom face - yellow */
        gl_color3f(0.86f, 0.86f, 0.20f);
        gl_vertex3f(-1.0f, -1.0f, -1.0f);
        gl_vertex3f( 1.0f, -1.0f, -1.0f);
        gl_vertex3f( 1.0f, -1.0f,  1.0f);
        gl_vertex3f(-1.0f, -1.0f,  1.0f);
        
        /* Right face - magenta */
        gl_color3f(0.86f, 0.20f, 0.86f);
        gl_vertex3f( 1.0f, -1.0f, -1.0f);
        gl_vertex3f( 1.0f,  1.0f, -1.0f);
        gl_vertex3f( 1.0f,  1.0f,  1.0f);
        gl_vertex3f( 1.0f, -1.0f,  1.0f);
        
        /* Left face - cyan */
        gl_color3f(0.20f, 0.86f, 0.86f);
        gl_vertex3f(-1.0f, -1.0f, -1.0f);
        gl_vertex3f(-1.0f, -1.0f,  1.0f);
        gl_vertex3f(-1.0f,  1.0f,  1.0f);
        gl_vertex3f(-1.0f,  1.0f, -1.0f);
        
        gl_end();
        
        /* Draw edges */
        gl_begin(GL_LINES);
        gl_color3f(1.0f, 1.0f, 1.0f);
        
        /* Front edges */
        gl_vertex3f(-1.0f, -1.0f,  1.0f); gl_vertex3f( 1.0f, -1.0f,  1.0f);
        gl_vertex3f( 1.0f, -1.0f,  1.0f); gl_vertex3f( 1.0f,  1.0f,  1.0f);
        gl_vertex3f( 1.0f,  1.0f,  1.0f); gl_vertex3f(-1.0f,  1.0f,  1.0f);
        gl_vertex3f(-1.0f,  1.0f,  1.0f); gl_vertex3f(-1.0f, -1.0f,  1.0f);
        
        /* Back edges */
        gl_vertex3f(-1.0f, -1.0f, -1.0f); gl_vertex3f( 1.0f, -1.0f, -1.0f);
        gl_vertex3f( 1.0f, -1.0f, -1.0f); gl_vertex3f( 1.0f,  1.0f, -1.0f);
        gl_vertex3f( 1.0f,  1.0f, -1.0f); gl_vertex3f(-1.0f,  1.0f, -1.0f);
        gl_vertex3f(-1.0f,  1.0f, -1.0f); gl_vertex3f(-1.0f, -1.0f, -1.0f);
        
        /* Connecting edges */
        gl_vertex3f(-1.0f, -1.0f,  1.0f); gl_vertex3f(-1.0f, -1.0f, -1.0f);
        gl_vertex3f( 1.0f, -1.0f,  1.0f); gl_vertex3f( 1.0f, -1.0f, -1.0f);
        gl_vertex3f( 1.0f,  1.0f,  1.0f); gl_vertex3f( 1.0f,  1.0f, -1.0f);
        gl_vertex3f(-1.0f,  1.0f,  1.0f); gl_vertex3f(-1.0f,  1.0f, -1.0f);
        
        gl_end();
        
        gl_context_end_frame(context);
        gl_ksdos_swap_buffers();
        
        delay(DEMO_DELAY);
        
        if (kbd_key_available()) {
            kbd_getchar();
            break;
        }
    }
    
    /* Cleanup */
    gl_destroy_context(context);
    vbe_shutdown();
}

/* ================================================================ */
/* Real OpenGL PS1 Demo                                             */
/* ================================================================ */

void gl_real_demo_psx(void) {
    vbe_init();
    
    /* Create OpenGL context */
    GLuint context = gl_create_context((void*)0xE0000000, 640, 480, 32);
    gl_make_current(context);
    
    /* Setup OpenGL state */
    gl_clear_color(0.08f, 0.04f, 0.31f, 1.0f);  /* PSX-style blue */
    gl_matrix_mode(GL_PROJECTION);
    gl_load_identity();
    gl_ortho(-160.0f, 160.0f, -120.0f, 120.0f, -1.0f, 1.0f);
    gl_matrix_mode(GL_MODELVIEW);
    gl_load_identity();
    
    /* Animation loop */
    for (int frame = 0; frame < DEMO_FRAMES; frame++) {
        gl_context_begin_frame(context);
        
        /* Draw sky gradient */
        gl_begin(GL_QUADS);
        for (int y = 0; y < 240; y++) {
            GLfloat sky_r = 0.08f + (GLfloat)y / 240.0f * 0.08f;
            GLfloat sky_g = 0.04f + (GLfloat)y / 240.0f * 0.06f;
            GLfloat sky_b = 0.31f + (GLfloat)y / 240.0f * 0.33f;
            
            gl_color3f(sky_r, sky_g, sky_b);
            gl_vertex2f(-160.0f, (GLfloat)(120 - y));
            gl_vertex2f(160.0f, (GLfloat)(120 - y));
            gl_vertex2f(160.0f, (GLfloat)(119 - y));
            gl_vertex2f(-160.0f, (GLfloat)(119 - y));
        }
        gl_end();
        
        /* Draw ground */
        gl_begin(GL_QUADS);
        for (int y = 240; y < 480; y++) {
            GLfloat ground_val = 0.12f + (GLfloat)(y - 240) / 240.0f * 0.17f;
            gl_color3f(ground_val, ground_val + 0.04f, ground_val / 2.0f);
            gl_vertex2f(-160.0f, (GLfloat)(120 - y));
            gl_vertex2f(160.0f, (GLfloat)(120 - y));
            gl_vertex2f(160.0f, (GLfloat)(119 - y));
            gl_vertex2f(-160.0f, (GLfloat)(119 - y));
        }
        gl_end();
        
        /* Animated triangles */
        GLfloat angle = (GLfloat)frame * 0.02f;
        GLfloat radius = 80.0f + 20.0f * sinf(angle * 3.0f);
        
        gl_begin(GL_TRIANGLES);
        gl_color3f(0.71f, 0.08f, 0.08f);  /* Red triangle */
        gl_vertex2f(0.0f + radius * cosf(angle), 
                   0.0f + radius * sinf(angle));
        gl_vertex2f(0.0f + radius * cosf(angle + 2.094f), 
                   0.0f + radius * sinf(angle + 2.094f));
        gl_vertex2f(0.0f + radius * cosf(angle + 4.189f), 
                   0.0f + radius * sinf(angle + 4.189f));
        
        gl_color3f(0.08f, 0.08f, 0.71f);  /* Blue triangle */
        gl_vertex2f(0.0f + radius * cosf(angle + 3.141f), 
                   0.0f + radius * sinf(angle + 3.141f));
        gl_vertex2f(0.0f + radius * cosf(angle + 5.235f), 
                   0.0f + radius * sinf(angle + 5.235f));
        gl_vertex2f(0.0f + radius * cosf(angle + 1.571f), 
                   0.0f + radius * sinf(angle + 1.571f));
        gl_end();
        
        /* Draw triangle outlines */
        gl_begin(GL_LINE_LOOP);
        gl_color3f(1.0f, 1.0f, 1.0f);
        for (int i = 0; i < 3; i++) {
            GLfloat vertex_angle = angle + i * 2.094f;
            gl_vertex2f(radius * cosf(vertex_angle), radius * sinf(vertex_angle));
        }
        gl_end();
        
        gl_begin(GL_LINE_LOOP);
        for (int i = 0; i < 3; i++) {
            GLfloat vertex_angle = angle + 3.141f + i * 2.094f;
            gl_vertex2f(radius * cosf(vertex_angle), radius * sinf(vertex_angle));
        }
        gl_end();
        
        /* Text overlay would go here in a real implementation */
        
        gl_context_end_frame(context);
        gl_ksdos_swap_buffers();
        
        delay(DEMO_DELAY);
        
        if (kbd_key_available()) {
            kbd_getchar();
            break;
        }
    }
    
    gl_destroy_context(context);
    vbe_shutdown();
}

/* ================================================================ */
/* Real OpenGL DOOM Demo                                            */
/* ================================================================ */

void gl_real_demo_doom(void) {
    vbe_init();
    
    /* Create OpenGL context */
    GLuint context = gl_create_context((void*)0xE0000000, 640, 480, 32);
    gl_make_current(context);
    
    /* Setup OpenGL state */
    gl_clear_color(0.12f, 0.16f, 0.08f, 1.0f);  /* DOOM-style green */
    gl_matrix_mode(GL_PROJECTION);
    gl_load_identity();
    gl_ortho(-320.0f, 320.0f, -240.0f, 240.0f, -1.0f, 1.0f);
    gl_matrix_mode(GL_MODELVIEW);
    gl_load_identity();
    
    /* Simple map for raycaster */
    const char map[16][16] = {
        "################",
        "#..............#",
        "#.#............#",
        "#.#............#",
        "#....##.........#",
        "#....##.........#",
        "#..............#",
        "#..............#",
        "#...#....#.....#",
        "#...#....#.....#",
        "#..............#",
        "#..............#",
        "#..............#",
        "#..............#",
        "#..............#",
        "################"
    };
    
    /* Animation loop */
    for (int frame = 0; frame < DEMO_FRAMES; frame++) {
        gl_context_begin_frame(context);
        
        /* Draw sky */
        gl_begin(GL_QUADS);
        for (int y = 0; y < 240; y++) {
            GLfloat sky_val = 0.12f + (GLfloat)y / 240.0f * 0.18f;
            gl_color3f(sky_val, sky_val + 0.04f, sky_val + 0.32f);
            gl_vertex2f(-320.0f, (GLfloat)(240 - y));
            gl_vertex2f(320.0f, (GLfloat)(240 - y));
            gl_vertex2f(320.0f, (GLfloat)(239 - y));
            gl_vertex2f(-320.0f, (GLfloat)(239 - y));
        }
        gl_end();
        
        /* Draw floor */
        gl_begin(GL_QUADS);
        for (int y = 240; y < 480; y++) {
            GLfloat floor_val = 0.24f + (GLfloat)(y - 240) / 240.0f * 0.16f;
            gl_color3f(floor_val * 0.33f, floor_val * 0.5f, floor_val * 0.25f);
            gl_vertex2f(-320.0f, (GLfloat)(240 - y));
            gl_vertex2f(320.0f, (GLfloat)(240 - y));
            gl_vertex2f(320.0f, (GLfloat)(239 - y));
            gl_vertex2f(-320.0f, (GLfloat)(239 - y));
        }
        gl_end();
        
        /* Raycaster rendering */
        GLfloat player_x = 8.0f, player_y = 8.0f;
        GLfloat player_angle = (GLfloat)frame * 0.01f;
        
        for (int x = 0; x < 640; x++) {
            GLfloat ray_angle = player_angle + ((GLfloat)x - 320.0f) * 0.001f;
            GLfloat ray_dx = cosf(ray_angle);
            GLfloat ray_dy = sinf(ray_angle);
            
            GLfloat distance = 0.0f;
            for (int step = 0; step < 200; step++) {
                distance += 0.1f;
                GLfloat test_x = player_x + ray_dx * distance;
                GLfloat test_y = player_y + ray_dy * distance;
                
                int map_x = (int)test_x;
                int map_y = (int)test_y;
                
                if (map_x < 0 || map_x >= 16 || map_y < 0 || map_y >= 16 || 
                    map[map_y][map_x] == '#') {
                    break;
                }
            }
            
            /* Draw wall slice */
            GLfloat wall_height = 480.0f / (distance + 0.1f);
            if (wall_height > 480.0f) wall_height = 480.0f;
            
            GLfloat brightness = 1.0f - distance / 20.0f;
            if (brightness < 0.2f) brightness = 0.2f;
            
            /* Alternate wall colors */
            if ((int)(ray_angle * 10) % 2 == 0) {
                gl_color3f(brightness * 0.33f, brightness * 0.25f, brightness * 0.5f);
            } else {
                gl_color3f(brightness * 0.5f, brightness * 0.33f, brightness * 0.25f);
            }
            
            GLfloat wall_top = 240.0f - wall_height / 2.0f;
            GLfloat wall_bottom = 240.0f + wall_height / 2.0f;
            
            gl_begin(GL_QUADS);
            gl_vertex2f((GLfloat)x - 320.0f, wall_top);
            gl_vertex2f((GLfloat)x - 319.0f, wall_top);
            gl_vertex2f((GLfloat)x - 319.0f, wall_bottom);
            gl_vertex2f((GLfloat)x - 320.0f, wall_bottom);
            gl_end();
        }
        
        gl_context_end_frame(context);
        gl_ksdos_swap_buffers();
        
        delay(DEMO_DELAY / 3);  /* Faster for smoother animation */
        
        if (kbd_key_available()) {
            kbd_getchar();
            break;
        }
    }
    
    gl_destroy_context(context);
    vbe_shutdown();
}

/* ================================================================ */
/* Performance Benchmark Demo                                         */
/* ================================================================ */

void gl_performance_benchmark(void) {
    vbe_init();
    
    GLuint context = gl_create_context((void*)0xE0000000, 640, 480, 32);
    gl_make_current(context);
    
    gl_clear_color(0.0f, 0.0f, 0.0f, 1.0f);
    
    /* Check hardware capabilities */
    GLboolean hw_3d = GL_FALSE, hw_tex = GL_FALSE, hw_blend = GL_FALSE, hw_depth = GL_FALSE;
    gl_hardware_get_capabilities(&hw_3d, &hw_tex, &hw_blend, &hw_depth);
    
    /* Benchmark triangles */
    const int triangle_count = 10000;
    
    gl_context_begin_frame(context);
    gl_clear(GL_COLOR_BUFFER_BIT);
    
    gl_begin(GL_TRIANGLES);
    for (int i = 0; i < triangle_count; i++) {
        GLfloat r = (GLfloat)i / triangle_count;
        GLfloat g = 1.0f - r;
        GLfloat b = 0.5f;
        
        gl_color3f(r, g, b);
        gl_vertex2f(-320.0f + r * 640.0f, -240.0f + g * 480.0f);
        gl_vertex2f(-320.0f + g * 640.0f, -240.0f + r * 480.0f);
        gl_vertex2f(-320.0f + b * 640.0f, -240.0f + b * 480.0f);
    }
    gl_end();
    
    gl_context_end_frame(context);
    gl_ksdos_swap_buffers();
    
    /* Get statistics */
    gl_context_stats_t stats;
    gl_context_get_statistics(&stats);
    
    gl_destroy_context(context);
    vbe_shutdown();
}

/* ================================================================ */
/* Multi-Context Demo                                                */
/* ================================================================ */

void gl_multi_context_demo(void) {
    vbe_init();
    
    /* Create multiple contexts */
    GLuint ctx1 = gl_create_context((void*)0xE0000000, 320, 240, 32);
    GLuint ctx2 = gl_create_context((void*)0xE0100000, 320, 240, 32);
    
    if (!ctx1 || !ctx2) {
        return;
    }
    
    /* Render to first context */
    gl_make_current(ctx1);
    gl_clear_color(1.0f, 0.0f, 0.0f, 1.0f);
    gl_clear(GL_COLOR_BUFFER_BIT);
    
    gl_begin(GL_TRIANGLES);
    gl_color3f(1.0f, 1.0f, 1.0f);
    gl_vertex2f(-50.0f, -50.0f);
    gl_vertex2f(50.0f, -50.0f);
    gl_vertex2f(0.0f, 50.0f);
    gl_end();
    
    /* Render to second context */
    gl_make_current(ctx2);
    gl_clear_color(0.0f, 1.0f, 0.0f, 1.0f);
    gl_clear(GL_COLOR_BUFFER_BIT);
    
    gl_begin(GL_QUADS);
    gl_color3f(1.0f, 1.0f, 1.0f);
    gl_vertex2f(-50.0f, -50.0f);
    gl_vertex2f(50.0f, -50.0f);
    gl_vertex2f(50.0f, 50.0f);
    gl_vertex2f(-50.0f, 50.0f);
    gl_end();
    
    /* Cleanup */
    gl_destroy_context(ctx1);
    gl_destroy_context(ctx2);
    vbe_shutdown();
}
