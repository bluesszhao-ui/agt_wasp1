#include <stddef.h>

/* Freestanding byte-copy routine used when libc is not linked. */
void *memcpy(void *dest, const void *src, size_t n)
{
  unsigned char *d = (unsigned char *)dest;
  const unsigned char *s = (const unsigned char *)src;
  while (n-- != 0u) {
    *d++ = *s++;
  }
  return dest;
}
