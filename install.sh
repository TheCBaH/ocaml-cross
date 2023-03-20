#!/bin/sh
set -eu
set -x
src=$1;shift
dst=$1;shift
cross=$1;shift
rm -rf $dst;mkdir -p $dst/bin $dst/libexec/ocaml.$cross

dirs="\
 bin\
 lib\
 man\
"
for d in $dirs; do
    cp -alp $src/$d $dst/libexec/ocaml.$cross
done

wrapper_byte="$dst/libexec/ocaml.$cross/bin/$cross-ocaml.wrapper.byte"
cat <<'_EOF_' >$wrapper_byte
#/bin/sh
set -eu
#set -x
self="$0"
name=$(basename $self)
dir_bin="$(dirname $(readlink -f $self))"
tool="${name##%CROSS%-}"
export OCAMLLIB="$(readlink -f $dir_bin/../lib/ocaml)"
exec $dir_bin/ocamlrun $dir_bin/$tool "$@"
_EOF_

wrapper_native="$dst/libexec/ocaml.$cross/bin/$cross-ocaml.wrapper.native"
cat <<'_EOF_' >$wrapper_native
#/bin/sh
set -eu
#set -x
self="$0"
name=$(basename $self)
dir_bin="$(dirname $(readlink -f $self))"
tool="${name##%CROSS%-}"
export OCAMLLIB="$(readlink -f $dir_bin/../lib/ocaml)"
exec $dir_bin/$tool "$@"
_EOF_

sed -i "s/%CROSS%/$cross/" $wrapper_byte $wrapper_native
chmod +x $wrapper_byte $wrapper_native

tools_bc="\
ocaml
"

tools_bc="$tools_bc\
 ocamlc.byte\
 ocamlopt.byte\
"

tools="\
 ocamlopt\
 ocamlc\
 ocamlmklib\
 ocamldep\
 ocamlcp\
"

tools="$tools\
 ocamlrun\
"
for t in $tools_bc; do
    ln -s $(basename $wrapper_byte) $dst/libexec/ocaml.$cross/bin/$cross-$t
done

for t in $tools; do
    ln -s $(basename $wrapper_native) $dst/libexec/ocaml.$cross/bin/$cross-$t
done

for t in $tools $tools_bc; do
    ln -s ../libexec/ocaml.$cross/bin/$cross-$t $dst/bin/$cross-$t
done
