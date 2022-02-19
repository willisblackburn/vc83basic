SOURCES = startup.s arch_sim6502.s util.s
OBJECTS = $(SOURCES:.s=.o)

TEST_COMMON_SOURCES = util_wrappers.s
TEST_COMMON_OBJECTS = $(TEST_COMMON_SOURCES:.s=.o)
TEST_SOURCES = util_test.c
TEST_OBJECTS = $(TEST_SOURCES:.c=.o)
TESTS = $(TEST_SOURCES:.c=)

CL65 = cl65
ARCH = -t sim6502
ASMFLAGS = $(ARCH) --create-dep $(<:.s=.d)
CCFLAGS = $(ARCH) --create-dep $(<:.c=.d)
LDFLAGS = $(ARCH) -m $@.map

all: basic $(TESTS)

basic: $(OBJECTS)
	$(CL65) $(LDFLAGS) -o $@ $^

$(TESTS): %: %.o $(TEST_COMMON_OBJECTS) $(filter-out startup.o,$(OBJECTS))
	$(CL65) $(LDFLAGS) -o $@ $^

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
	rm -f $(TARGET) *.o *.d *.map
