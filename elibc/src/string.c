#include <string.h>
void *memset(void *s, int c, size_t n) { unsigned char *p=(unsigned char*)s; while(n--)*p++=(unsigned char)c; return s; }
void *memcpy(void *d, const void *s, size_t n) { unsigned char *dd=(unsigned char*)d; const unsigned char *ss=(const unsigned char*)s; while(n--)*dd++=*ss++; return d; }
size_t strlen(const char *s) { size_t l=0; while(*s++)l++; return l; }
int strcmp(const char *a, const char *b) { while(*a&&*a==*b){a++;b++;} return*(const unsigned char*)a-*(const unsigned char*)b; }
