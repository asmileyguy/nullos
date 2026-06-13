#include <freestanding/stdint.h>
#include <freestanding/stddef.h>
#include <freestanding/signal.h>
#include <io/terminal.h>
#include <main/panic.h>
#include <main/halt.h>
#include <main/scheduler.h>
#include <mm/vmm.h>

__attribute__((noreturn)) void panic(const char *reason) {
    cli();

    uint64_t rip = (uint64_t)__builtin_return_address(0);
    uint64_t rsp;
    __asm__ volatile("mov %%rsp, %0" : "=r"(rsp));

    printf("\n--- KERNEL PANIC ---\n");
    printf("reason: %s\n", reason);
    printf("rip: %p  rsp: %p\n", rip, rsp);
    halt();
}

// Decode page fault error code bits (Intel SDM Vol.3 §4.7)
static void print_pf_error(uint64_t ec) {
    printf("  pf error: 0x%lx  [", ec);
    printf("%s", (ec & (1 << 0)) ? "PROT"    : "NP"    ); // 0: not-present / protection violation
    printf(" %s", (ec & (1 << 1)) ? "WRITE"  : "READ"  ); // 1: write / read
    printf(" %s", (ec & (1 << 2)) ? "USER"   : "KERNEL"); // 2: user / kernel
    printf("%s",  (ec & (1 << 3)) ? " RSVD"  : ""      ); // 3: reserved bit set in PTE
    printf("%s",  (ec & (1 << 4)) ? " IFETCH": ""      ); // 4: instruction fetch (NX violation)
    printf("%s",  (ec & (1 << 5)) ? " PK"    : ""      ); // 5: protection-key violation
    printf("]\n");
}

static void print_regs(exception_frame_t *f) {
    printf("\nregisters:\n");
    printf("  rip: %p  rsp: %p  rflags: %p\n", f->rip, f->rsp, f->rflags);
    printf("  rax: %p  rbx: %p  rcx: %p\n",    f->rax, f->rbx, f->rcx);
    printf("  rdx: %p  rsi: %p  rdi: %p\n",    f->rdx, f->rsi, f->rdi);
    printf("  rbp: %p  r8:  %p  r9:  %p\n",    f->rbp, f->r8,  f->r9);
    printf("  r10: %p  r11: %p  r12: %p\n",    f->r10, f->r11, f->r12);
    printf("  r13: %p  r14: %p  r15: %p\n",    f->r13, f->r14, f->r15);
    printf("  cs:  %p  ss:  %p\n",             f->cs,  f->ss);
}

__attribute__((noreturn)) void exception_panic(exception_frame_t *frame) {
    const char *reason;
    switch (frame->vector) {
        case 0:   reason = "division by zero";               break;
        case 4:   reason = "overflow";                       break;
        case 5:   reason = "bound range exceeded";           break;
        case 6:   reason = "invalid opcode";                 break;
        case 7:   reason = "device not available";           break;
        case 8:   reason = "double fault";                   break;
        case 13:  reason = "general protection fault";       break;
        case 14:  reason = "page fault";                     break;
        case 30:  reason = "security exception";             break;
        case 512: reason = "reserved exception";             break;
        default:  reason = "unknown exception";              break;
    }

    int from_user = (frame->cs & 3) != 0;

    if (from_user) {
        printf("\nuserspace fault (pid %d): %s\n", current_task_ptr->pid, reason);
    } else {
        printf("\n--- KERNEL PANIC ---\n");
        printf("exception: %s  (vector %lu, error 0x%lx)\n",
               reason, frame->vector, frame->error_code);
    }

    // For page faults, read CR2 (faulting virtual address) and decode the error code.
    if (frame->vector == 14) {
        uint64_t cr2;
        __asm__ volatile("mov %%cr2, %0" : "=r"(cr2));
        printf("  fault addr (cr2): %p\n", cr2);
        print_pf_error(frame->error_code);
    } else if (frame->vector == 13) {
        printf("  error code: 0x%lx\n", frame->error_code);
    }

    print_regs(frame);

    if (from_user) {
        sti();
        exit_task(128 + SIGSEGV);
        __builtin_unreachable();
    }

    halt();
}
