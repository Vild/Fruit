GENERIC_VERT := generic.vert.spv
GENERIC_FRAG := generic.frag.spv

GENERIC = $(GENERIC_VERT) $(GENERIC_FRAG)

.PHONY: ALWAYS

all: $(GENERIC)

%.spv: % ALWAYS
	glslangValidator -V $* -o $@