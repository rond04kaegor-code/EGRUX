#include <unistd.h>
#include <stdint.h>
static int syscall(int n, int a, int b, int c){int r;asm volatile("int $0x80":"=a"(r):"a"(n),"b"(a),"c"(b),"d"(c):"memory");return r;}
ssize_t read(int fd, void *buf, size_t n){return(ssize_t)syscall(3,fd,(int)(uintptr_t)buf,(int)n);}
ssize_t write(int fd, const void *buf, size_t n){return(ssize_t)syscall(4,fd,(int)(uintptr_t)buf,(int)n);}
void _exit(int s){syscall(1,s,0,0);while(1){asm volatile("hlt");}}
