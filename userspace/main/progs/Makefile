# progs/Makefile - links and strips programs
ifeq ($(filter --no-print-directory,$(MAKEFLAGS)),)
MAKEFLAGS += --no-print-directory
endif
ifeq ($(filter --silent,$(MAKEFLAGS)),)
MAKEFLAGS += --silent
endif

.DEFAULT_GOAL := all

include ../../config.mk

PROGS = $(filter-out hello_musl, $(patsubst main/%.c,%,$(wildcard main/*.c)) $(patsubst main/%.S,%,$(wildcard main/*.S)))
MUSL_PROGS = hello_musl
TARGETS = $(foreach p,$(PROGS),../../$(p))
MUSL_TARGETS = $(foreach p,$(MUSL_PROGS),../../$(p))

all: main $(MUSL_TARGETS)
	@needs_build=0; \
	for p in $(PROGS); do \
		t="../../$$p"; \
		o="main/$$p.o"; \
		if [ ! -f $$t ] || [ $$o -nt $$t ] || [ ../../crt0.o -nt $$t ] || [ ../../libc.a -nt $$t ] || [ ../../ld.so -nt $$t ]; then \
			needs_build=1; \
		fi; \
	done; \
	if [ $$needs_build -eq 0 ]; then \
		printf "  %-7s %s\n" "INFO" "$(foreach p,$(PROGS),$(SUBDIR)/$(p)) are already up to date"; \
	else \
		$(MAKE) $(TARGETS); \
	fi

main:
	@$(MAKE) -C main

define PROG_rule
../../$(1): main/$(1).o ../../crt0.o ../../libc.so ../../libc.a ../../ld.so Makefile ../../config.mk
	@printf "  %-7s %s\n" "LD" "$(SUBDIR)/$(1)"
	$(LD) $(LDFLAGS) ../../crt0.o main/$(1).o -o $$@ -L../.. -Wl,--dynamic-linker=/usr/lib/ld.so -l:libc.so
	@printf "  %-7s %s\n" "STRIP" "$(SUBDIR)/$(1)"
	$(STRIP) $(STRIPFLAGS) $$@
endef
$(foreach p,$(PROGS),$(eval $(call PROG_rule,$(p))))

define MUSL_PROG_rule
../../$(1): main/$(1).c ../../extra/musl-install/lib/libc.a Makefile ../../config.mk
	@printf "  %-7s %s\n" "MUSL-LD" "$(SUBDIR)/$(1)"
	$(CC) -static -nostdlib \
		../../extra/musl-install/lib/crt1.o \
		../../extra/musl-install/lib/crti.o \
		$$($(CC) -print-file-name=crtbeginT.o) \
		$$< \
		-I../../extra/musl-install/include \
		-L../../extra/musl-install/lib \
		-lc -lgcc -lgcc_eh \
		$$($(CC) -print-file-name=crtend.o) \
		../../extra/musl-install/lib/crtn.o \
		-o $$@
	# @printf "  %-7s %s\n" "STRIP" "$(SUBDIR)/$(1)"
	# $(STRIP) $(STRIPFLAGS) $$@
endef
$(foreach p,$(MUSL_PROGS),$(eval $(call MUSL_PROG_rule,$(p))))

clean:
	@$(MAKE) -C main clean
	@printf "  %-7s %s\n" "CLEAN" "$(foreach p,$(PROGS),$(SUBDIR)/$(p))"
	@rm -f $(TARGETS)

mrproper: clean

.PHONY: all main clean mrproper
