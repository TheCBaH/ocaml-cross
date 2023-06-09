
all:
	echo "Not supported" >&2

MAKEFLAGS += --no-builtin-rules

.SUFFIXES:

BUILD_DIR=_build
TEST_DIR=test/_build
DKMLDIR=${BUILD_DIR}/dkmldir
BIN_DIR=_bin
DKML_DEBUG=DKML_BUILD_TRACE=ON DKML_BUILD_TRACE_LEVEL=1

empty:=
space+= ${empty} ${empty}

extract:
	if [ -d ${BIN_DIR} ]; then chmod -R u+w ${BIN_DIR}; fi
	rm -rf ${BUILD_DIR} ${BIN_DIR}
	mkdir -p ${BUILD_DIR} ${BIN_DIR}
	mkdir -p ${DKMLDIR}/vendor/drc ${DKMLDIR}/vendor/dkml-compiler/env ${DKMLDIR}/vendor/dkml-compiler/src
	cp -ap dkml-runtime-common/* ${DKMLDIR}/vendor/drc/
	cp -ap dkml-compiler/env/* ${DKMLDIR}/vendor/dkml-compiler/env/
	cp -ap dkml-compiler/src/* ${DKMLDIR}/vendor/dkml-compiler/src
	cp dkml-runtime-common/template.dkmlroot ${DKMLDIR}/.dkmlroot

OCAML_VER=4.12.1
DKML_ARGS=\
 -f src-ocaml\
 -g mlcross\
 -elinux_x86_64\

TARGETS=\
 aarch64\
 powerpc64\
 riscv64\
 s390x\
 x86_64\

add_arch=$(if $(shell type $1-linux-musl || true),$1-linux-musl=$(realpath ${BUILD_DIR}/$1-linux-musl))

configure:
	env TOPDIR=${DKMLDIR}/vendor/drc/all/emptytop\
	 DKML_REPRODUCIBLE_SYSTEM_BREWFILE=/dev/null\
	 ${DKML_DEBUG}\
	 bash -x ${DKMLDIR}/vendor/dkml-compiler/src/r-c-ocaml-1-setup.sh\
	 -d ${DKMLDIR}\
	 -t ${BIN_DIR}\
	 -v ocaml.git\
	 -z\
	 ${DKML_ARGS}\
	 -a "$(subst ${space},;,$(strip $(foreach t,${TARGETS},$(call add_arch,${t}))))"\
	 -k vendor/dkml-compiler/env/standard-compiler-env-to-ocaml-configure-env.sh

CPU_CORES=$(shell getconf _NPROCESSORS_ONLN 2>/dev/null)

native.build.patch-alpine:
	sed -i 's/INJECT_CFLAGS=.*/INJECT_CFLAGS="-Wno-misleading-indentation"/'\
	 ${BIN_DIR}/share/dkml/repro/100co/vendor/dkml-compiler/env/standard-compiler-env-to-ocaml-configure-env.sh

native.build.patch-manylinux2014:
	sed -i 's/INJECT_CFLAGS=.*/INJECT_CFLAGS="-fPIC"/'\
	 ${BIN_DIR}/share/dkml/repro/100co/vendor/dkml-compiler/env/standard-compiler-env-to-ocaml-configure-env.sh

native.build.patch-manylinux2010: native.build.patch-manylinux2014
	sed -r -i 's/(__secure_getenv)/\1_undefined/g' ${BIN_DIR}/src-ocaml/configure ${BIN_DIR}/src-ocaml/configure.ac

native.build.patch-manylinux1: native.build.patch-manylinux2010
	sed -i '1 i #define _GNU_SOURCE' ${BIN_DIR}/src-ocaml/ocamltest/run_unix.c ${BIN_DIR}/src-ocaml/otherlibs/unix/socketaddr.c
	sed -i '1 i #define _XOPEN_SOURCE 500' ${BIN_DIR}/src-ocaml/otherlibs/systhreads/st_stubs.c

native.build:
	cd ${BIN_DIR} && env\
	 NUMCPUS=${CPU_CORES}\
	 ${DKML_DEBUG}\
	 share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-2-build_host-noargs.sh

native.test:
	${MAKE} cross.test TARGET=

linux-musl.targets: $(addsuffix -linux-musl.cross,${TARGETS})

build: extract linux-musl.targets configure native.build native.test

%.cross:
	./cross.sh '' $(basename $@) > ${BUILD_DIR}/$(basename $@)

host_from_target=$(word 1, $(subst -,${space},$1))-unknown-linux
HOST=$(call host_from_target, ${TARGET})

cross.build: TARGET=aarch64-linux-musl
cross.build:
	${MAKE} ${TARGET}.cross
	${TARGET}-gcc --version
	cp ${BUILD_DIR}/${TARGET} ${BIN_DIR}/share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-targetabi-${TARGET}.sh
	cd ${BIN_DIR} && env TOPDIR=${DKMLDIR}/vendor/drc/all/emptytop\
	 _DKML_SYSTEM_PATH=/bin:/usr/bin:/usr/local/bin:${HOME}/.local/bin\
	 ${DKML_DEBUG}\
	 env NUMCPUS=${CPU_CORES} share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-3-build_cross.sh\
	 ${DKML_ARGS}\
	 -t .\
	 -d share/dkml/repro/100co\
	 -s ${OCAML_VER}\
	 -a ${TARGET}=vendor/dkml-compiler/src/r-c-ocaml-targetabi-${TARGET}.sh\
	 -n "--host=$(call host_from_target, ${TARGET})"

cross.test: OCAML_BIN_DIR=$(abspath ${BIN_DIR}$(if ${TARGET},/mlcross/${TARGET})/bin)
cross.test: OCAML_CROSS=${OCAML_BIN_DIR}/
cross.test: TARGET=aarch64-linux-musl

cross.test:
	${MAKE} -C test $@ OCAML_CROSS=${OCAML_CROSS} TARGET=${TARGET}

dune.build:
	env PATH=$$(readlink -f ${BIN_DIR}/bin):$$PATH sh -xeuc 'cd dune; ocaml boot/bootstrap.ml --verbose'

repo:
	./repo.sh init
	./repo.sh update ${OCAML_VER}

%.print:
	@echo '$($(basename $@))'

cross.install: TARGET=aarch64-linux-musl
cross.install:
	mkdir -p ${TEST_DIR}
	./install.sh $(if ${TARGET}, ${BIN_DIR}/mlcross/${TARGET},${BIN_DIR}) ${TEST_DIR}/$(or ${TARGET},host) $(or ${TARGET}, host)

patches.make.repo:
	git -C ${REPO} format-patch $$(git ls-tree HEAD ${REPO} | awk '{print $$3}')
	mkdir -p $(basename $(basename $@))/${REPO}
	mkdir -p $(basename $(basename $@))/${REPO}
	mv -v ${REPO}/00* $(basename $(basename $@))/${REPO}/

patches.make:
	${MAKE} REPO=dkml-runtime-common $@.repo
	${MAKE} REPO=dkml-compiler $@.repo

patches.apply: REPO=dkml-runtime-common
patches.apply.repo:
	git -C ${REPO} checkout .
	set -eux; for p in $(wildcard $(realpath $(basename $(basename $@)))/${REPO}/*); do\
	  if [ -z "$(git config user.email)" ]; then\
	    git -C ${REPO} apply --verbose $$p;\
	  else\
	     git -C ${REPO} am $$p;\
	  fi;\
	done

patches.apply:
	${MAKE} REPO=dkml-runtime-common $@.repo
	${MAKE} REPO=dkml-compiler $@.repo

ID_OFFSET=$(or $(shell id -u docker 2>/dev/null),0)
UID=$(shell expr $$(id -u) - ${ID_OFFSET})
GID=$(shell expr $$(id -g) - ${ID_OFFSET})
WORKSPACE=$(or ${LOCAL_WORKSPACE_FOLDER},${CURDIR})
TERMINAL=$(shell test -t 0 && echo t)

USERSPEC=--user=${UID}:${GID}
image_name=${USER}_$(basename $(1))

debian.image_run: WORKSPACE_SUFFIX=/test

ubuntu.image_run: WORKSPACE_SUFFIX=/test

CURL_TAR=curl-7.88.1.tar.gz

${BUILD_DIR}/downloads/curl/${CURL_TAR}:
	mkdir -p $(basename $@)
	curl -o $@.tmp --location --show-error https://github.com/TheCBaH/git.builder/releases/download/v0.0.1/${CURL_TAR}
	mv $@.tmp $@

${BUILD_DIR}/downloads/ca-certificates.crt:
	cp /etc/ssl/certs/$(notdir $@) $@

manylinux1.image: ${BUILD_DIR}/downloads/curl/${CURL_TAR} ${BUILD_DIR}/downloads/ca-certificates.crt

%.image: Dockerfile-%
	env BUILDKIT_PROGRESS=plain docker build --tag $(call image_name,$@) ${DOCKER_BUILD_OPTS} -f $<\
	 $(if ${http_proxy},--build-arg http_proxy=${http_proxy})\
	 $(or ${DOCKER_BUILD_CONTEXT},.)
	rm -f $(filter ${BUILD_DIR}/downloads/%, $^)

%.image_run:
	docker run --rm --init --hostname $@ -i${TERMINAL} -w ${WORKSPACE}\
	 -v ${WORKSPACE}${WORKSPACE_SUFFIX}:${WORKSPACE}${WORKSPACE_SUFFIX}\
	 ${DOCKER_RUN_OPTS}\
	 ${USERSPEC} $(call image_name, $@) ${CMD}

%.image_print:
	@echo "$(call image_name, $@)"

NATIVE_TEST=${MAKE} -C $(dir ${TEST_DIR}) OCAML_CROSS=$(notdir ${TEST_DIR})/host/bin/host- TARGET= cross.test
native_install.test:
	${NATIVE_TEST}

RELOCATED_IMAGE=debian
native_relocated.test:
	${MAKE} ${RELOCATED_IMAGE}.image_run CMD='${NATIVE_TEST}'

CROSS_TEST=${MAKE} -C $(dir ${TEST_DIR}) OCAML_CROSS=$(notdir ${TEST_DIR})/${TARGET}/bin/${TARGET}- TARGET=${TARGET} cross.test

cross_install.test: TARGET=aarch64-linux-musl
cross_install.test:
	${CROSS_TEST}

cross_relocated.test: TARGET=aarch64-linux-musl
cross_relocated.test:
	${MAKE} ${RELOCATED_IMAGE}.image_run CMD='${CROSS_TEST}'

clean:
	if [ -d ${BIN_DIR} ]; then chmod -R u+w ${BIN_DIR}; fi
	rm -rf ${BUILD_DIR} ${TEST_DIR} ${BIN_DIR}
