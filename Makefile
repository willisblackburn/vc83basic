TARGETS = sim6502
TEST_TARGET = sim6502

TESTS = parser_test program_test util_test

ASMFLAGS = --create-dep $(@:.o=.d)
CFLAGS = --create-dep $(@:.o=.d)
LDFLAGS = -m $@.map

all: $(addprefix basic_,$(TARGETS))

# Goal: basic_sim6502
basic_sim6502: basic_sim6502.s basic.inc
	cl65 -t sim6502 $(LDFLAGS) -o $@ $<

# Tests
test: $(addprefix run_,$(TESTS))

define create-test
run_$1: $1
	sim65 $1

$1: $1.o basic_tests.o
	cl65 -t $(TEST_TARGET) $(LDFLAGS) -o $$@ $$^

clean::
	rm -f $1
endef

$(foreach TEST,$(TESTS),$(eval $(call create-test,$(TEST))))

# Object files for tests
basic_tests.o: basic_tests.s basic.inc
	cl65 -t $(TEST_TARGET) -c $(ASMFLAGS) -o $@ $<

%.o: %.c
	cl65 -t $(TEST_TARGET) -c $(CFLAGS) -o $@ $<

.PHONY: all test clean

clean::
	rm -f $(addprefix basic_,$(TARGETS)) basic_tests.o *.o *.d *.map

-include *.d
