SOURCES = crt0.s arch_sim6502.s
OBJECTS = $(SOURCES:.s=.o)

TARGET = sim6502

CC = cl65
ASMFLAGS = -t $(TARGET) --create-dep $(<:.s=.d)
LDFLAGS = -t $(TARGET) -m $@.map

basic: $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.s
	$(CC) -c $(ASMFLAGS) -o $@ $<

clean:
	rm -f basic $(OBJECTS) *.d *.map