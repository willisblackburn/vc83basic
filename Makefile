# SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
#
# SPDX-License-Identifier: MIT

TARGETS = sim6502 apple2 apple2_lc atari ac6502 vc83_serial
TEST_TARGET = sim6502

TESTS = $(notdir $(basename $(wildcard tests/*_test.c)))
EXPECT_TESTS = $(notdir $(basename $(wildcard expect_tests/*.exp)))

ASMFLAGS = --create-dep $(@:.o=.d)
CFLAGS = --create-dep $(@:.o=.d)
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

all: $(addprefix basic_,$(TARGETS))

# Goal: basic_sim6502
basic_sim6502.o: basic_sim6502.s basic.s constants.inc zeropage.s version.inc
	cl65 -t sim6502 -c $(ASMFLAGS) -o $@ $<

basic_sim6502: basic_sim6502.o
	cl65 -t sim6502 -C sim6502/sim6502.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_apple2
basic_apple2.o: basic_apple2.s basic.s constants.inc zeropage.s version.inc
	cl65 -t apple2 -c $(ASMFLAGS) -o $@ $<

basic_apple2: basic_apple2.o
	cl65 -t apple2 -C apple2/apple2.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_apple2_lc
basic_apple2_lc.o: basic_apple2_lc.s basic.s constants.inc zeropage.s version.inc
	cl65 -t apple2 -c $(ASMFLAGS) -o $@ $<

basic_apple2_lc: basic_apple2_lc.o
	cl65 -t apple2 -C apple2/apple2_lc.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_atari
basic_atari.o: basic_atari.s basic.s constants.inc zeropage.s version.inc
	cl65 -t atari -c $(ASMFLAGS) -o $@ $<

basic_atari: basic_atari.o
	cl65 -t atari -C atari/atari.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_ac6502
basic_ac6502.o: basic_ac6502.s basic.s constants.inc zeropage.s version.inc
	cl65 -t none -c $(ASMFLAGS) -o $@ $<

basic_ac6502: basic_ac6502.o
	cl65 -t none -C ac6502/ac6502.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

# Goal: basic_vc83_serial
basic_vc83_serial.o: basic_vc83_serial.s basic.s constants.inc zeropage.s version.inc
	cl65 -t none -c $(ASMFLAGS) -o $@ $<

basic_vc83_serial: basic_vc83_serial.o
	cl65 -t none -C vc83_serial/vc83_serial.cfg $(LDFLAGS) -o $@ $<
	$(PRINT_SIZE)

basic_vc83_serial.mem: basic_vc83_serial
	if command -v srec_cat >/dev/null; then srec_cat $< -Binary -offset 0x0400 -Output $@ -VMem 8; else echo "srec_cat not installed"; touch $@; fi 

# Rule for version.inc
version.inc: FORCE
	@echo '$(GIT_VERSION)' | cmp -s - $@ || echo '$(GIT_VERSION)' > $@

# Rules for building the constants files:
constants.inc: constants.m4
	m4 $< >$@

constants.h: constants.m4
	m4 -D__C__ $< >$@

# Rules for building the zero page files:
zeropage.s: zeropage.m4
	m4 -DOUTPUT=s $< >$@

zeropage.h: zeropage.m4
	m4 -DOUTPUT=h $< >$@

# Unit tests
test: $(addprefix run_,$(TESTS))

run_%: tests/%
	sim65 $<

tests/%: tests/%.o basic_tests.o
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg $(LDFLAGS) -o $@ $^

tests/%.o: tests/%.c constants.h zeropage.h tests/test.h
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg -c $(CFLAGS) -o $@ $<

basic_tests.o: basic_tests.s basic.s constants.inc zeropage.s version.inc
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg -c $(ASMFLAGS) -o $@ $<

clean::
	rm -f $(addprefix tests/,$(TESTS))

# Integration tests
expect_test: basic_sim6502 $(addprefix run_expect_test_,$(EXPECT_TESTS))

run_expect_test_%:
	expect expect_tests/$*.exp

.PHONY: all test expect_test clean FORCE
.SECONDARY:

clean::
	rm -f $(addprefix basic_,$(TARGETS)) basic_tests.o constants.inc constants.h zeropage.s zeropage.h version.inc *.o *.d *.map *.dbg tests/*.o tests/*.d tests/*.map tests/*.dbg

-include $(addsuffix .d,$(addprefix basic_,$(TARGETS)))
-include $(addsuffix .d,$(addprefix tests/,$(TESTS)))
-include basic_tests.d
