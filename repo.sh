#!/bin/sh
set -x
set -eu
cmd=$1;shift

repo=ocaml

with_retry() {
    rc=0
    for i in $(seq 1 10); do
        if "$@" ; then
            break
        fi
        rc=$?
        sleep $(expr 1 + $(od -A n -t d -N 1 /dev/urandom) % 5)
    done
    if [ $rc -ne 0 ]; then
        exit $rc
    fi
}
_git="git -C $repo.git"
case "$cmd" in
init)
    ref=${1:-trunk}
    if [ ! -d $repo.git ]; then
        git init $repo.git
        $_git remote add origin -t $ref https://github.com/$repo/$repo.git
    fi
    for b in 4.12 4.13 4.14 5.0; do
        $_git remote set-branches --add origin $b
    done
    with_retry $_git -c protocol.version=2 fetch --no-tags --depth 1 origin
    $_git submodule sync
    $_git submodule update --jobs 2 --depth 1 --init
    $_git config user.email "you@example.com"
    $_git config user.name "Your Name"
    ;;
update)
    ref=$1;shift
    if [ -d $repo ]; then
        $_git checkout .
        $_git clean -xdf
    else
        cp -rl $repo.git $repo
    fi
    with_retry $_git -c protocol.version=2 fetch --no-tags --depth 1 origin $ref
    $_git reset --hard FETCH_HEAD
    $_git -c protocol.version=2 submodule update --jobs 2 --depth 1 --init
    $_git clean -xdf
    $_git tag -f r-c-ocaml-1-setup-srctree
    $_git submodule foreach git tag -f r-c-ocaml-1-setup-srctree
    ;;
esac
