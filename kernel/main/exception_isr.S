.intel_syntax noprefix

.section .text
// We dont put our ISRS here, our macros already handle that
.global isrrsv
.global isrhdr

.extern exception_panic

/*
Table of all CPU faults:
  0: Divide error | Does not push an error code
  1: Debug | Does not push an error code
  2: Non-Maskable Interrupt | Does not push an error code
  3: Breakpoint | Does not push an error code
  4: Overflow | Does not push an error code
  5: Bound Range Exceeded | Does not push an error code
  6: Invalid Opcode | Does not push an error code
  7: Device Not Available | Does not push an error code
  8: Double Fault | Always pushes 0 as error code
  9: Coprocessor Segment Overrun | Does not push an error code
  10: Invalid TSS | Pushes an error code
  11: Segment Not Present | Pushes an error code
  12: Stack Segment Fault | Pushes an error code
  13: General Protection Fault | Pushes an error code
  14: Page Fault | Pushes an error code
  15: Reserved | Does not push an error code
  16: x87 Floating Point Exception | Does not push an error code
  17: Alignment Check | Pushes an error code
  18: Machine Check | Does not push an error code
  19: SIMD Floating Point Exception | Does not push an error code
  20: Virtualization Exception | Does not push an error code
  21: Control Protection Exception  | Pushes an error code
  22-27: Reserved | Does not push an error code
  28: Hypervisor Injection Exception | Does not push an error code
  29: VMM Communication Exception | Pushes an error code
  30: Security Exception | Pushes an error code
  31: Reserved | Does not push an error code
*/

.macro ISR_NOERR vector
    .global isr\vector
    isr\vector:
        push 0              // dummy error code
        push \vector        // vector number
        jmp isrhdr
.endm

.macro ISR_ERR vector
    .global isr\vector
    isr\vector:
        push \vector        // vector number (error code already on stack)
        jmp isrhdr
.endm

ISR_NOERR 0
ISR_NOERR 4
ISR_NOERR 5
ISR_NOERR 6
ISR_NOERR 7
ISR_ERR   8
ISR_ERR   13
ISR_ERR   14
ISR_ERR   30

// Reserved ISRs (22-27, 31): dummy error code + sentinel vector 512
isrrsv:
    push 0      // dummy error code
    push 512    // sentinel: reserved exception
    jmp isrhdr

// Stack layout at entry to isrhdr (growing downward):
//   [rsp+0]   = vector
//   [rsp+8]   = error_code        (pushed by CPU or dummy 0)
//   [rsp+16]  = rip               (pushed by CPU)
//   [rsp+24]  = cs                (pushed by CPU)
//   [rsp+32]  = rflags            (pushed by CPU)
//   [rsp+40]  = rsp (user)        (pushed by CPU, ring-3 only)
//   [rsp+48]  = ss  (user)        (pushed by CPU, ring-3 only)
//
// After saving all GP registers we pass a pointer to the full exception_frame_t
// to exception_panic so it can print a complete register dump.

isrhdr:
    // Save all caller-saved and callee-saved GP registers.
    // We push in this order so the struct layout in panic.h matches:
    //   rdi, rsi, rdx, rcx, r8, r9, r10, r11, ds, es  (then vector/errcode/CPU frame above)
    // Plus the extra regs not pushed yet: rax, rbx, rbp, r12, r13, r14, r15
    push r15
    push r14
    push r13
    push r12
    push rbp
    push rbx
    push rax

    push rdi
    push rsi
    push rdx
    push rcx
    push r8
    push r9
    push r10
    push r11

    // Save segments
    mov ax, ds
    push rax
    mov ax, es
    push rax

    // Swap GS if we came from user space.
    // Frame layout from RSP after all pushes:
    //   +0   = es
    //   +8   = ds
    //   +16  = r11
    //   +24  = r10
    //   +32  = r9
    //   +40  = r8
    //   +48  = rcx
    //   +56  = rdx
    //   +64  = rsi
    //   +72  = rdi
    //   +80  = rax
    //   +88  = rbx
    //   +96  = rbp
    //   +104 = r12
    //   +112 = r13
    //   +120 = r14
    //   +128 = r15
    //   +136 = vector
    //   +144 = error_code
    //   +152 = rip
    //   +160 = cs
    //   +168 = rflags
    //   +176 = rsp (user, ring-3 only)
    //   +184 = ss  (user, ring-3 only)
    mov rax, [rsp + 160]    // CS
    test al, 3
    jz .no_swap_entry
    swapgs
.no_swap_entry:

    // Load kernel data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax

    // exception_panic(frame*)  -- RSP points at the exception_frame_t
    mov rdi, rsp
    call exception_panic

    // exception_panic is noreturn for both kernel and userspace faults,
    // so we never reach here. The iretq path is kept only as a safety net.

    // Swap GS back if returning to user space
    mov rax, [rsp + 160]    // cs
    test al, 3
    jz .no_swap_exit
    swapgs
.no_swap_exit:

    // Restore segments
    pop rax
    mov es, ax
    pop rax
    mov ds, ax

    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi

    pop rax
    pop rbx
    pop rbp
    pop r12
    pop r13
    pop r14
    pop r15

    // Clean up vector and error code
    add rsp, 16
    iretq
