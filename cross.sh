#!/bin/sh
set -eux
path=$1;shift;
toolchain=$1;shift;
if [ -n "$path" ]; then
    path="$(readlink -f $path)/"
fi
cat <<_EOF_
autodetect_compiler_CC="$path$toolchain-gcc"
autodetect_compiler_CFLAGS=
autodetect_compiler_CXX="$path$toolchain-g++"
autodetect_compiler_CXXFLAGS=
autodetect_compiler_AS="$path$toolchain-as"
autodetect_compiler_ASFLAGS=
autodetect_compiler_LD="$path$toolchain-ld"
autodetect_compiler_LDFLAGS=
autodetect_compiler_LDLIBS=

export_binding AR "$path$toolchain-ar"
export_binding ASPP "$path$toolchain-cc -c"
export_binding DIRECT_LD "$path$toolchain-ld"
export_binding NM "$path$toolchain-nm"
export_binding OBJDUMP "$path$toolchain-objdump"
export_binding RANLIB "$path$toolchain-ranlib"
export_binding STRIP "$path$toolchain-strip"
_EOF_
