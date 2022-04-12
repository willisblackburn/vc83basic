SOURCES = startup.s target_sim6502.s
OBJECTS = $(SOURCES:.s=.o)

TARGET = -t sim6502
ASMFLAGS = $(TARGET) --create-dep $(<:.s=.d)
LDFLAGS = $(TARGET) -m $@.map

basic: $(OBJECTS)
	cl65 $(LDFLAGS) -o $@ $^

%.o: %.s
	cl65 -c $(ASMFLAGS) -o $@ $<

ifneq ($(MAKECMDGOALS), clean)
-include $(SOURCES:.s=.d)
endif

clean:
	rm -f basic *.o *.d *.map
