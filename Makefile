SOURCES = basic_sim6502.s
OBJECTS = $(SOURCES:.s=.o)

CL65 = cl65
ARCH = -t sim6502
ASMFLAGS = $(ARCH) --create-dep $(<:.s=.d)
LDFLAGS = $(ARCH) -m $@.map

TARGET = basic_sim6502

$(TARGET): $(OBJECTS)
	$(CL65) $(LDFLAGS) -o $@ $^

%.o: %.s
	$(CL65) -c $(ASMFLAGS) -o $@ $<

ifneq ($(MAKECMDGOALS), clean)
-include $(SOURCES:.s=.d)
endif

clean:
	rm -f $(TARGET) *.o *.d *.map
