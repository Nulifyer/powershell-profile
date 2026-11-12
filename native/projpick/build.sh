#!/bin/sh
# Builds bin/projpick.exe (cross-compiles from Linux/macOS/Windows with Zig).
set -e
cd "$(dirname "$0")"
mkdir -p ../../bin
zig test src/fuzzy.zig --cache-dir .zig-cache
zig build-exe src/main.zig -target x86_64-windows-gnu -O ReleaseFast --subsystem windows -fstrip \
    --name projpick -femit-bin=../../bin/projpick.exe --cache-dir .zig-cache
rm -f ../../bin/projpick.pdb ../../bin/projpick.lib
ls -l ../../bin/projpick.exe
