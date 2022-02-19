SOURCES = startup.s arch_sim6502.s util.s
OBJECTS = $(SOURCES:.s=.o)

TEST_COMMON_SOURCES = c_wrappers.s
TEST_COMMON_OBJECTS = $(TEST_COMMON_SOURCES:.s=.o)
TEST_SOURCES = util_test.c
TEST_OBJECTS = $(TEST_SOURCES:.c=.o)
TESTS = $(TEST_SOURCES:.c=)
RUN_TESTS = $(addsuffix .run, $(TESTS))

CL65 = cl65
ARCH = -t sim6502
ASMFLAGS = $(ARCH) --create-dep $(<:.s=.d)
CCFLAGS = $(ARCH) --create-dep $(<:.c=.d)
LDFLAGS = $(ARCH) -m $@.map

all: basic $(TESTS)

basic: $(OBJECTS)
	$(CL65) $(LDFLAGS) -o $@ $^

test: $(RUN_TESTS)

$(TESTS): %: %.o $(TEST_COMMON_OBJECTS) $(filter-out startup.o, $(OBJECTS))
	$(CL65) $(LDFLAGS) -o $@ $^

$(RUN_TESTS): %.run: %
	sim65 $^

%.o: %.s
	$(CL65) -c $(ASMFLAGS) -o $@ $<

%.o: %.c
	$(CL65) -c $(CCFLAGS) -o $@ $<

ifneq ($(MAKECMDGOALS), clean)
-include $(SOURCES:.s=.d)
-include $(TEST_COMMON_SOURCES:.s=.d)
-include $(TEST_SOURCES:.c=.d)
endif

clean:
	rm -f basic $(TESTS) *.o *.d *.map
