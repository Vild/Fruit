#!/bin/bash

function compile() {
	glslangValidator -V res/shader/$1 -o res/shader/$1.spv
}

compile generic.vert
compile generic.frag