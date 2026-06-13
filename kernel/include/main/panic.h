#pragma once

#include <freestanding/stdint.h>

// Full CPU state captured by the exception ISR stub.
// Fields are ordered to match the exact push sequence in exception_isr.S.
// isrhdr pushes (last push = lowest address = first struct field):
//   es, ds, r11, r10, r9, r8, rcx, rdx, rsi, rdi, rax, rbx, rbp, r12, r13, r14, r15
// then the ISR macro pushed vector and the CPU pushed error_code/rip/cs/rflags/rsp/ss.
typedef struct {
    uint64_t es, ds;
    uint64_t r11, r10, r9, r8;
    uint64_t rcx, rdx, rsi, rdi;
    uint64_t rax, rbx, rbp;
    uint64_t r12, r13, r14, r15;
    // Pushed by the ISR macro
    uint64_t vector;
    uint64_t error_code;
    // Pushed by the CPU on exception entry
    uint64_t rip;
    uint64_t cs;
    uint64_t rflags;
    uint64_t rsp;   // only valid when coming from ring 3
    uint64_t ss;    // only valid when coming from ring 3
} exception_frame_t;

__attribute__((noreturn)) void panic(const char *reason);
__attribute__((noreturn)) void exception_panic(exception_frame_t *frame);