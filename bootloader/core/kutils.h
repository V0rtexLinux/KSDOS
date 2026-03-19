#ifndef KUTILS_H
#define KUTILS_H

#include <stddef.h> // Se não tiver, use: #define NULL ((void*)0)

// Protótipos das funções que o compilador sentiu falta
int kstrcmp(const char *s1, const char *s2);
void kcopy(void *dest, const void *src, size_t n);
size_t slen(const char *s);
void delay(int count);

// Protótipo da função de vídeo
void tty_fill(int x, int y, int w, char c, unsigned char attr);

#endif
