#!/bin/sh
# Linux (opsional): butuh libSDL3.so
fpc -Mobjfpc -Sh -O2 -vew main.pas && ./main
