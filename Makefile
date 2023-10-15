TARGETS = sim6502 apple2

TEST_TARGET = sim6502

COMMON_SOURCES = data.s main.s parser.s program.s util.s
COMMON_OBJECTS = $(COMMON_SOURCES:.s=.o)

TESTS = $(notdir $(basename $(wildcard tests/*_test.c)))

TEST_COMMON_SOURCES = \
	tests/c_wrappers.s \
	$(filter-out $(TEST_TARGET)/$(TEST_TARGET)_startup.s,$(wildcard $(TEST_TARGET)/*.s))
TEST_COMMON_OBJECTS = $(TEST_COMMON_SOURCES:.s=.o)

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
	cl65 -t $1 -C $1/$1.cfg $$(LDFLAGS) -o $$@ $$^

# Builds a target-specific object from a common source
$1/%.o: %.s
	cl65 -t $1 -C $1/$1.cfg -c $$(ASMFLAGS) -o $$@ $$<

# Builds a target-specific object from a target-specific source
$1/%.o: $1/%.s
	cl65 -t $1 -C $1/$1.cfg -c $$(ASMFLAGS) -o $$@ $$<

-include $$(TARGET_$1_SOURCES:.s=.d)

clean::
	rm -f basic_$1 $1/*.o $1/*.d $1/*.map

endef

# create-test defines rules to build and run a test.

define create-test

run_$1: tests/$1
	sim65 tests/$1

tests/$1: tests/$1.o $$(TEST_COMMON_OBJECTS) $$(COMMON_OBJECTS)
	cl65 -t $$(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg $$(TEST_LDFLAGS) -o $$@ $$^

-include $1.d

clean::
	rm -f tests/$1

endef

.PHONY: all test clean

all: $(addprefix basic_,$(TARGETS))

test: $(addprefix run_,$(TESTS))

$(foreach TARGET,$(TARGETS),$(eval $(call create-target,$(TARGET))))

$(foreach TEST,$(TESTS),$(eval $(call create-test,$(TEST))))

# Builds a common object from a common assembly language source; used by tests
%.o: %.s
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg -c $(TEST_ASMFLAGS) -o $@ $<

# Same but for a C source
%.o: %.c
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg -c $(TEST_CFLAGS) -o $@ $<

-include $$(COMMON_SOURCES:.s=.d)

clean::
	rm -f *.o *.d *.map tests/*.o tests/*.d tests/*.map
