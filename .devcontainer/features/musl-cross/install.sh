#!/bin/sh
set -e
set -x

echo "Activating feature 'musl-cross'"
dest=${1:-/usr/local}

ARCHITECTURES=${ARCHITECTURES:-undefined}
echo "Selected architectures: $ARCHITECTURES"

base_url='https://github.com/TheCBaH/musl-cross-make.builder/releases/download'
ver='v0.0.2'
gcc='9.4.0'
host='static'

for arch in ${ARCHITECTURES}; do
# https://github.com/TheCBaH/musl-cross-make.builder/releases/download/v0.0.2/musl-cross-aarch64-linux-musl-gcc9.4.0-static.tar.xz
    fname="musl-cross-$arch-linux-musl-gcc$gcc-$host.tar.xz"
    url="$base_url/$ver/$fname"
    wget $url --progress=dot:giga  -O /tmp/$fname
    tar -xf /tmp/$fname -C ${1:-/usr/local}
    rm -f /tmp/$fname
done
