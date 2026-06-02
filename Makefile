# SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
#
# SPDX-License-Identifier: MIT

TARGETS = sim6502 apple2 apple2_lc atari ac6502 vc83_serial
TEST_TARGET = sim6502

TESTS = $(notdir $(basename $(wildcard tests/*_test.c)))
EXPECT_TESTS = $(notdir $(basename $(wildcard expect_tests/*.exp)))

ASMFLAGS = --create-dep $(@:.o=.d) --asm-include-dir src
CFLAGS = --create-dep $(@:.o=.d) -I src
LDFLAGS = -m $@.map -vm

GIT_VERSION := .byte "$(shell git describe --always --dirty 2>/dev/null || echo unknown)"

PRINT_SIZE = @sum=0; \
	for size in $$(awk '/^(CODE|PARSER|VEC|XVEC|FUNC|XFUNC) / { print $$4 }' $@.map); do \
		sum=$$(($$sum + 0x$$size)); \
	done; \
	printf "Code size: \$$%X (%d)\n" $$sum $$sum

# Define DEBUG=1 to build with debug symbols
ifeq ($(DEBUG),1)
ASMFLAGS += -g
CFLAGS += -g
LDFLAGS += -Wl --dbgfile,$@.dbg
endif

all: $(addprefix build/basic_,$(TARGETS))

# Goal: basic_sim6502
build/basic_sim6502.o: targets/sim6502/basic_sim6502.s src/basic.s src/constants.inc src/zeropage.s src/version.inc
	@mkdir -p $(@D)
	cl65 -t sim6502 -c $(ASMFLAGS) --asm-include-dir targets/sim6502 -o $@ $<

build/basic_sim6502: build/basic_sim6502.o
	@mkdir -p $(@D)
	cl65 -t sim6502 -C targets/sim6502/sim6502.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_apple2
build/basic_apple2.o: targets/apple2/basic_apple2.s src/basic.s src/constants.inc src/zeropage.s src/version.inc
	@mkdir -p $(@D)
	cl65 -t apple2 -c $(ASMFLAGS) --asm-include-dir targets/apple2 -o $@ $<

build/basic_apple2: build/basic_apple2.o
	@mkdir -p $(@D)
	cl65 -t apple2 -C targets/apple2/apple2.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_apple2_lc
build/basic_apple2_lc.o: targets/apple2/basic_apple2_lc.s src/basic.s src/constants.inc src/zeropage.s src/version.inc
	@mkdir -p $(@D)
	cl65 -t apple2 -c $(ASMFLAGS) --asm-include-dir targets/apple2 -o $@ $<

build/basic_apple2_lc: build/basic_apple2_lc.o
	@mkdir -p $(@D)
	cl65 -t apple2 -C targets/apple2/apple2_lc.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_atari
build/basic_atari.o: targets/atari/basic_atari.s src/basic.s src/constants.inc src/zeropage.s src/version.inc
	@mkdir -p $(@D)
	cl65 -t atari -c $(ASMFLAGS) --asm-include-dir targets/atari -o $@ $<

build/basic_atari: build/basic_atari.o
	@mkdir -p $(@D)
	cl65 -t atari -C targets/atari/atari.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_ac6502
build/basic_ac6502.o: targets/ac6502/basic_ac6502.s src/basic.s src/constants.inc src/zeropage.s src/version.inc
	@mkdir -p $(@D)
	cl65 -t none -c $(ASMFLAGS) --asm-include-dir targets/ac6502 -o $@ $<

build/basic_ac6502: build/basic_ac6502.o
	@mkdir -p $(@D)
	cl65 -t none -C targets/ac6502/ac6502.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_vc83_serial
build/basic_vc83_serial.o: targets/vc83_serial/basic_vc83_serial.s src/basic.s src/constants.inc src/zeropage.s src/version.inc
	@mkdir -p $(@D)
	cl65 -t none -c $(ASMFLAGS) --asm-include-dir targets/vc83_serial -o $@ $<

build/basic_vc83_serial: build/basic_vc83_serial.o
	@mkdir -p $(@D)
	cl65 -t none -C targets/vc83_serial/vc83_serial.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

build/basic_vc83_serial.mem: build/basic_vc83_serial
	@mkdir -p $(@D)
	if command -v srec_cat >/dev/null; then srec_cat $< -Binary -offset 0x0400 -Output $@ -VMem 8; else echo "srec_cat not installed"; touch $@; fi 

# Rule for version.inc
src/version.inc: FORCE
	@mkdir -p $(@D)
	@echo '$(GIT_VERSION)' | cmp -s - $@ || echo '$(GIT_VERSION)' > $@

# Rules for building the constants files:
src/constants.inc: src/constants.m4
	@mkdir -p $(@D)
	m4 $< >$@

src/constants.h: src/constants.m4
	@mkdir -p $(@D)
	m4 -D__C__ $< >$@

# Rules for building the zero page files:
src/zeropage.s: src/zeropage.m4
	@mkdir -p $(@D)
	m4 -DOUTPUT=s $< >$@

src/zeropage.h: src/zeropage.m4
	@mkdir -p $(@D)
	m4 -DOUTPUT=h $< >$@

# Unit tests
test: $(addprefix run_,$(TESTS))

run_%: build/tests/%
	sim65 $<

build/tests/%: build/tests/%.o build/tests/basic_tests.o
	@mkdir -p $(@D)
	cl65 -t $(TEST_TARGET) -C targets/$(TEST_TARGET)/$(TEST_TARGET).cfg $(LDFLAGS) -o $@ $^

build/tests/%.o: tests/%.c src/constants.h src/zeropage.h tests/test.h
	@mkdir -p $(@D)
	cl65 -t $(TEST_TARGET) -C targets/$(TEST_TARGET)/$(TEST_TARGET).cfg -c $(CFLAGS) -o $@ $<

build/tests/basic_tests.o: tests/basic_tests.s src/basic.s src/constants.inc src/zeropage.s src/version.inc
	@mkdir -p $(@D)
	cl65 -t $(TEST_TARGET) -C targets/$(TEST_TARGET)/$(TEST_TARGET).cfg -c $(ASMFLAGS) --asm-include-dir targets/sim6502 --asm-include-dir tests -o $@ $<

# Integration tests
expect_test: build/basic_sim6502 $(addprefix run_expect_test_,$(EXPECT_TESTS))

run_expect_test_%:
	expect expect_tests/$*.exp

.PHONY: all test expect_test clean FORCE
.SECONDARY:

clean::
	rm -rf build/
	rm -f src/constants.inc src/constants.h src/zeropage.s src/zeropage.h src/version.inc

-include $(addsuffix .d,$(addprefix build/basic_,$(TARGETS)))
-include $(addsuffix .d,$(addprefix build/tests/,$(TESTS)))
-include build/tests/basic_tests.d
