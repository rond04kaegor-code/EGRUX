#include <stdio.h>
#include <string.h>
static void itoa(unsigned int v, char *s, int b, int sign) {
    int i=0; if(v==0){s[i++]='0';s[i]=0;return;}
    while(v){int r=(int)(v%(unsigned)b);s[i++]=(char)((r>9)?r-10+'a':r+'0');v/=(unsigned)b;}
    if(sign)s[i++]='-'; s[i]=0;
    for(int j=0,k=i-1;j<k;j++,k--){char t=s[j];s[j]=s[k];s[k]=t;}
}
int vsnprintf(char *buf, size_t sz, const char *fmt, va_list ap) {
    if(!buf||!sz)return 0; size_t w=0; char tmp[32];
    while(*fmt&&w<sz-1){if(*fmt!='%'){buf[w++]=*fmt++;continue;} fmt++;
        switch(*fmt){
            case 'd':{int v=va_arg(ap,int);unsigned u=(unsigned)(v<0?-v:v);itoa(u,tmp,10,v<0);for(char*p=tmp;*p&&w<sz-1;p++)buf[w++]=*p;break;}
            case 's':{char*s=va_arg(ap,char*);if(!s)s="(null)";while(*s&&w<sz-1)buf[w++]=*s++;break;}
            case 'c':buf[w++]=(char)va_arg(ap,int);break;
            case '%':buf[w++]='%';break;
        } fmt++;
    } buf[w]=0; return (int)w;
}
int printf(const char *f, ...){char b[4096];va_list a;va_start(a,f);int r=vsnprintf(b,sizeof(b),f,a);va_end(a);for(int i=0;i<r;i++)putchar(b[i]);return r;}
