#!/bin/sh
set -eu
#set -x
image=$1;shift
cmd="$@"
exec make $image.image_run CMD="$cmd"
