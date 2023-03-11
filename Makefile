
all:
	echo "Not supported" >&2

MAKEFLAGS += --no-builtin-rules

.SUFFIXES:

BUILD=_build
TEST=test/_build
DKMLDIR=${BUILD}/dkmldir
BIN=_bin
DKML_DEBUG=DKML_BUILD_TRACE=ON DKML_BUILD_TRACE_LEVEL=1
empty:=
space+= ${empty} ${empty}

extract:
	rm -rf ${BUILD} ${BIN}
	mkdir -p ${BUILD} ${BIN}
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

add_arch=$(if $(shell which $1-linux-musl || true),$1-linux-musl=$(realpath ${BUILD}/$1-linux-musl))

configure:
	env TOPDIR=${DKMLDIR}/vendor/drc/all/emptytop\
	 DKML_REPRODUCIBLE_SYSTEM_BREWFILE=/dev/null\
	 ${DKML_DEBUG}\
	 ${DKMLDIR}/vendor/dkml-compiler/src/r-c-ocaml-1-setup.sh\
	 -d ${DKMLDIR}\
	 -t ${BIN}\
	 -v ocaml.git\
	 -z\
	 ${DKML_ARGS}\
	 -a "$(subst ${space},;,$(strip $(foreach t,${TARGETS},$(call add_arch,${t}))))"\
	 -k vendor/dkml-compiler/env/standard-compiler-env-to-ocaml-configure-env.sh

native.build:
	cd ${BIN} && share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-2-build_host-noargs.sh

native.test:
	${MAKE} cross.test TARGET=

build: extract $(addsuffix -linux-musl.cross,${TARGETS}) configure native.build native.test

%.cross:
	./cross.sh '' $(basename $@) > ${BUILD}/$(basename $@)

host_from_target=$(word 1, $(subst -,${space},$1))-unknown-linux
HOST=$(call host_from_target, ${TARGET})

cross.build: TARGET=aarch64-linux-musl
cross.build:
	${MAKE} ${TARGET}.cross
	${TARGET}-gcc --version
	cp ${BUILD}/${TARGET} ${BIN}/share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-targetabi-${TARGET}.sh
	cd ${BIN} && env TOPDIR=${DKMLDIR}/vendor/drc/all/emptytop\
	 ${DKML_DEBUG}\
	 sh -x share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-3-build_cross.sh\
	 ${DKML_ARGS}\
	 -t .\
	 -d share/dkml/repro/100co\
	 -s ${OCAML_VER}\
	 -a ${TARGET}=vendor/dkml-compiler/src/r-c-ocaml-targetabi-${TARGET}.sh\
	 -n "--host=$(call host_from_target, ${TARGET})"

cross.test: OCAML_BIN=$(abspath ${BIN}$(if ${TARGET},/mlcross/${TARGET})/bin)
cross.test: OCAML_CROSS=${OCAML_BIN}/
cross.test: TARGET=aarch64-linux-musl

cross.test:
	${MAKE} -C test $@ OCAML_CROSS=${OCAML_CROSS} TARGET=${TARGET}

dune.build:
	env PATH=$$(readlink -f ${BIN}/bin):$$PATH sh -xeuc 'cd dune; ocaml boot/bootstrap.ml --verbose'

repo:
	./repo.sh init
	./repo.sh update ${OCAML_VER}

%.print:
	@echo '$($(basename $@))'

cross.install: TARGET=aarch64-linux-musl
cross.install:
	mkdir -p ${TEST}
	./install.sh $(if ${TARGET}, ${BIN}/mlcross/${TARGET},${BIN}) ${TEST}/$(or ${TARGET},host) $(or ${TARGET}, host)
	${MAKE} OCAML_CROSS=$(abspath ${TEST}/$(or ${TARGET}, host)/bin)/$(or ${TARGET}, host)- $(basename $@).test

patches.make: REPO=dkml-runtime-common
patches.make:
	git -C ${REPO} format-patch $$(git ls-tree HEAD ${REPO} | awk '{print $$3}')
	mkdir -p $(basename $@)/${REPO}
	mkdir -p $(basename $@)/${REPO}
	mv -v ${REPO}/00* $(basename $@)/${REPO}/

patches.apply: REPO=dkml-runtime-common
patches.apply:
	git -C ${REPO} checkout .
	set -eux; for p in $(wildcard $(realpath $(basename $@))/${REPO}/*); do\
	 git -C ${REPO} apply --verbose $$p;\
	 echo git -C ${REPO}} am $$p;\
	done

ID_OFFSET=$(or $(shell id -u docker 2>/dev/null),0)
UID=$(shell expr $$(id -u) - ${ID_OFFSET})
GID=$(shell expr $$(id -g) - ${ID_OFFSET})
WORKSPACE=$(or ${LOCAL_WORKSPACE_FOLDER},${CURDIR})
TERMINAL=$(shell test -t 0 && echo t)

USERSPEC=--user=${UID}:${GID}
image_name=${USER}_$(basename $(1))

debian.image: DOCKER_BUILD_CONTEXT=.devcontainer/features
debian.image_run: WORKSPACE_SUFFIX=/test

ubuntu.image: DOCKER_BUILD_CONTEXT=.devcontainer/features
ubuntu.image_run: WORKSPACE_SUFFIX=/test

%.image: Dockerfile-%
	docker build --tag $(call image_name,$@) ${DOCKER_BUILD_OPTS} -f $^\
	 $(if ${http_proxy},--build-arg http_proxy=${http_proxy})\
	$(or ${DOCKER_BUILD_CONTEXT},.)

%.image_run:
	docker run --rm --init --hostname $@ -i${TERMINAL} -w ${WORKSPACE}\
	 -v ${WORKSPACE}${WORKSPACE_SUFFIX}:${WORKSPACE}${WORKSPACE_SUFFIX}\
	 ${DOCKER_RUN_OPTS}\
	 ${USERSPEC} $(call image_name, $@) ${CMD}

%.image_print:
	@echo "$(call image_name, $@)"

NATIVE_TEST=${MAKE} -C $(dir ${TEST}) OCAML_CROSS=$(notdir ${TEST})/host/bin/host- TARGET= cross.test
native_install.test:
	${NATIVE_TEST}

RELOCATED_IMAGE=debian
native_relocated.test:
	${MAKE} ${RELOCATED_IMAGE}.image_run CMD='${NATIVE_TEST}'

CROSS_TEST=${MAKE} -C $(dir ${TEST}) OCAML_CROSS=$(notdir ${TEST})/${TARGET}/bin/${TARGET}- TARGET=${TARGET} cross.test

cross_install.test: TARGET=aarch64-linux-musl
cross_install.test:
	${CROSS_TEST}

cross_relocated.test: TARGET=aarch64-linux-musl
cross_relocated.test:
	${MAKE} ${RELOCATED_IMAGE}.image_run CMD='${CROSS_TEST}'
