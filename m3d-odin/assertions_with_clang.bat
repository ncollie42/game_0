@echo off

clang m3d.c -std=c99 -o assertions.exe -DASSERTIONS
assertions.exe
del assertions.exe