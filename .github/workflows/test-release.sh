#!/bin/sh
set -eu
set -x
root=$1;shift
arch=$1;shift;
host=$1;shift

dst='.test'
for d in $root/*; do
    case $d in
    *-$arch-$host)
        echo "::group::$d"
        rm -rf $dst; mkdir -p $dst
        for f in $d/*.tar.xz; do
            tar -xf $(readlink -f $f) -C $dst
        done
        target="$arch-linux-musl"
        echo "::group::$d host"
        $dst/bin/host-ocaml --version
        $dst/bin/host-ocamlopt -config
        make -C test cross.test OCAML_CROSS=$(readlink -f $dst/bin/host-) TARGET=
        echo "::group::$d $target"
        $dst/bin/$arch-linux-musl-ocaml --version
        $dst/bin/$arch-linux-musl-ocamlopt -config
        make cross.test OCAML_CROSS=$(readlink -f $dst/bin/$target-) TARGET=$target
        ;;
    *)
        echo "Ignoring $d"
        ;;
    esac
done
