SOURCES = init.s io.s main.s parser.s program.s startup.s util.s
OBJECTS = $(SOURCES:.s=.o)

TEST_COMMON_SOURCES = c_wrappers.s
TEST_COMMON_OBJECTS = $(TEST_COMMON_SOURCES:.s=.o)
TEST_SOURCES = parser_test.c program_test.c util_test.c
TEST_OBJECTS = $(TEST_SOURCES:.c=.o)
TESTS = $(TEST_SOURCES:.c=)
RUN_TESTS = $(addsuffix .run, $(TESTS))

TARGET = -t sim6502

all: basic $(TESTS)

basic: $(OBJECTS)
	cl65 $(TARGET) -m $@.map -o $@ $^

test: $(RUN_TESTS)

$(TESTS): %: %.o $(TEST_COMMON_OBJECTS) $(filter-out startup.o, $(OBJECTS))
	cl65 $(TARGET) -m $@.map -o $@ $^

$(RUN_TESTS): %.run: %
	sim65 $^

%.o: %.s
	cl65 -c $(TARGET) --create-dep $(<:.s=.d) -o $@ $<

%.o: %.c
	cl65 -c $(TARGET) --create-dep $(<:.c=.d) -o $@ $<

ifneq ($(MAKECMDGOALS), clean)
-include $(SOURCES:.s=.d)
-include $(TEST_COMMON_SOURCES:.s=.d)
-include $(TEST_SOURCES:.c=.d)
endif

clean:
	rm -f basic $(TESTS) *.o *.d *.map
