# SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
#
# SPDX-License-Identifier: MIT

SOURCES = io.s startup.s
OBJECTS = $(SOURCES:.s=.o)

TARGET = -t sim6502

basic: $(OBJECTS)
	cl65 $(TARGET) -m $@.map -o $@ $^

%.o: %.s
	cl65 -c $(TARGET) --create-dep $(<:.s=.d) -o $@ $<

ifneq ($(MAKECMDGOALS), clean)
-include $(SOURCES:.s=.d)
endif

clean:
	rm -f basic *.o *.d *.map
