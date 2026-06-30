#include <stddef.h>

/* Freestanding byte-fill routine used when libc is not linked. */
void *memset(void *s, int c, size_t n)
{
  unsigned char *p = (unsigned char *)s;
  while (n-- != 0u) {
    *p++ = (unsigned char)c;
  }
  return s;
}
