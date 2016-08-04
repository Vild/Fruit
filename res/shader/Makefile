GENERIC_VERT := generic.vert.spv
GENERIC_FRAG := generic.frag.spv

GENERIC = $(GENERIC_VERT) $(GENERIC_FRAG)

all: $(GENERIC)

%.spv: %
	glslangValidator -V $^ -o $@