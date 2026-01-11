TARGETS = sim6502 apple2

TEST_TARGET = sim6502

COMMON_SOURCES = \
	control.s \
	decode.s \
    dim.s \
	expression.s \
	fp.s \
	functions.s \
	input.s \
	let.s \
	list.s \
	main.s \
	name.s \
	parser.s \
	poke.s \
	print.s \
	program.s \
	read.s \
	run.s \
	string.s \
	tables.s \
	util.s \
	zeropage.s
COMMON_OBJECTS = $(COMMON_SOURCES:.s=.o)

TESTS = $(notdir $(basename $(wildcard tests/*_test.c)))

TEST_COMMON_SOURCES = \
	tests/c_wrappers.s \
	$(filter-out $(TEST_TARGET)/$(TEST_TARGET)_startup.s,$(wildcard $(TEST_TARGET)/*.s))
TEST_COMMON_OBJECTS = $(TEST_COMMON_SOURCES:.s=.o)

EXPECT_TESTS = $(notdir $(basename $(wildcard expect_tests/*.exp)))

ASMFLAGS = --create-dep $(@:.o=.d)
CFLAGS = --create-dep $(@:.o=.d)
LDFLAGS = -m $@.map

TEST_ASMFLAGS = $(ASMFLAGS)
TEST_CFLAGS = $(CFLAGS)
TEST_LDFLAGS = $(LDFLAGS)

# create-target defines all the rules to build a single target.

define create-target

TARGET_$1_SOURCES = $$(wildcard $1/*.s)
TARGET_$1_OBJECTS = $$(TARGET_$1_SOURCES:.s=.o)

TARGET_$1_COMMON_OBJECTS = $(COMMON_SOURCES:%.s=$1/%.o)

basic_$1: $$(TARGET_$1_OBJECTS) $$(TARGET_$1_COMMON_OBJECTS)
	ld65 -C $1/$1.cfg $$(LDFLAGS) -o $$@ $$^ $1.lib

# Builds a target-specific object from a common source
$1/%.o: %.s constants.inc zeropage.inc basic.inc
	ca65 -t $1 $$(ASMFLAGS) -o $$@ $$<

# Builds a target-specific object from a target-specific source
$1/%.o: $1/%.s constants.inc zeropage.inc basic.inc
	ca65 -t $1 $$(ASMFLAGS) -o $$@ $$<

-include $$(TARGET_$1_SOURCES:.s=.d)

clean::
	rm -f basic_$1 $1/*.o $1/*.d $1/*.map

endef

# create-test defines rules to build and run a test.

define create-test

run_$1: tests/$1
	sim65 tests/$1

tests/$1: tests/$1.o $$(TEST_COMMON_OBJECTS) $$(COMMON_OBJECTS)
	ld65 -C $(TEST_TARGET)/$(TEST_TARGET).cfg $$(TEST_LDFLAGS) -o $$@ --dbgfile $$@.dbg $$^ $(TEST_TARGET).lib

-include $1.d

clean::
	rm -f tests/$1

endef

# create-expect-test defines rules to run a Expect test.

define create-expect-test

.PHONY: run_expect_test_$1

run_expect_test_$1:
	expect expect_tests/$1.exp

endef

.PHONY: all test expect_test clean

all: $(addprefix basic_,$(TARGETS))

test: $(addprefix run_,$(TESTS))

expect_test: $(addprefix run_expect_test_,$(EXPECT_TESTS))

# Rules for building the constants files:
constants.inc: constants.m4
	m4 $< >$@

constants.h: constants.m4
	m4 -D__C__ $< >$@

# Rules for building the zero page files:
zeropage.s: zeropage.m4
	m4 -DOUTPUT=s $< >$@

zeropage.inc: zeropage.m4
	m4 -DOUTPUT=inc $< >$@

zeropage.h: zeropage.m4
	m4 -DOUTPUT=h $< >$@

$(foreach TARGET,$(TARGETS),$(eval $(call create-target,$(TARGET))))

$(foreach TEST,$(TESTS),$(eval $(call create-test,$(TEST))))

$(foreach TEST,$(EXPECT_TESTS),$(eval $(call create-expect-test,$(TEST))))

# Builds a common object from a common assembly language source; used by tests
%.o: %.s constants.inc zeropage.inc basic.inc
	ca65 -g -t $(TEST_TARGET) $(TEST_ASMFLAGS) -o $@ $<

# Same but for a C source
%.o: %.c constants.h zeropage.h tests/test.h
	cc65 -g -t $(TEST_TARGET) $(TEST_CFLAGS) -o $*.s $<
	ca65 -g -t $(TEST_TARGET) $(TEST_CFLAGS) -o $@ $*.s

-include $$(COMMON_SOURCES:.s=.d)

clean::
	rm -f constants.inc constants.h zeropage.s zeropage.inc zeropage.h *.o *.d *.map tests/*.o tests/*.d tests/*.map
