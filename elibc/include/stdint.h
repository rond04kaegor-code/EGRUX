#ifndef _STDINT_H
#define _STDINT_H
typedef signed char int8_t; typedef unsigned char uint8_t;
typedef signed short int16_t; typedef unsigned short uint16_t;
typedef signed int int32_t; typedef unsigned int uint32_t;
typedef int32_t ssize_t; typedef uint32_t size_t;
typedef int32_t intptr_t; typedef uint32_t uintptr_t;
#define NULL ((void*)0)
#endif
