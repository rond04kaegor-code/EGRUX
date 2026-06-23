#ifndef _UNISTD_H
#define _UNISTD_H
#include <stdint.h>
#define STDIN_FILENO 0
#define STDOUT_FILENO 1
ssize_t read(int fd, void *buf, size_t count);
ssize_t write(int fd, const void *buf, size_t count);
void _exit(int status);
#endif
