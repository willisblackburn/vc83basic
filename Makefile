TARGETS = sim6502 apple2

COMMON_SOURCES = $(wildcard *.s)
COMMON_OBJECTS = $(COMMON_SOURCES:.s=.o)

ASMFLAGS = --create-dep $(@:.o=.d)
LDFLAGS = -m $@.map

# create-target defines all the rules to build a single target.

define create-target

TARGET_$1_SOURCES = $$(wildcard $1/*.s)
TARGET_$1_OBJECTS = $$(TARGET_$1_SOURCES:.s=.o)

TARGET_$1_COMMON_OBJECTS = $(COMMON_SOURCES:%.s=$1/%.o)

basic_$1: $$(TARGET_$1_OBJECTS) $$(TARGET_$1_COMMON_OBJECTS)
	cl65 -t $1 $$(LDFLAGS) -o $$@ $$^

$1/%.o: %.s
	cl65 -t $1 -c $$(ASMFLAGS) -o $$@ $$<

$1/%.o: $1/%.s
	cl65 -t $1 -c $$(ASMFLAGS) -o $$@ $$<

-include $$(TARGET_$1_SOURCES:.s=.d)

clean::
	rm -f basic_$1 $1/*.o $1/*.d $1/*.map

endef

all: $(addprefix basic_,$(TARGETS))

$(foreach TARGET,$(TARGETS),$(eval $(call create-target,$(TARGET))))

-include $$(COMMON_SOURCES:.s=.d)

clean::
	rm -f *.o *.d *.map
