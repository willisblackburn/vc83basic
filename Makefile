SOURCES = init.s io.s main.s parser.s program.s startup.s util.s
OBJECTS = $(SOURCES:.s=.o)

TEST_COMMON_SOURCES = c_wrappers.s
TEST_COMMON_OBJECTS = $(TEST_COMMON_SOURCES:.s=.o)
TEST_SOURCES = parser_test.c program_test.c util_test.c
TEST_OBJECTS = $(TEST_SOURCES:.c=.o)
TESTS = $(TEST_SOURCES:.c=)
RUN_TESTS = $(addsuffix .run, $(TESTS))

CL65 = cl65
TARGET = -t sim6502
ASMFLAGS = $(TARGET) --create-dep $(<:.s=.d)
CCFLAGS = $(TARGET) --create-dep $(<:.c=.d)
LDFLAGS = $(TARGET) -m $@.map

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
