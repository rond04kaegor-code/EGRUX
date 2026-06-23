#include <stdio.h>
#include <unistd.h>
int putchar(int c) { char ch=(char)c; write(STDOUT_FILENO,&ch,1); return (unsigned char)c; }
int getchar(void) { char c; if(read(STDIN_FILENO,&c,1)!=1)return -1; return (unsigned char)c; }
