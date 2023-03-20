
all:
	echo "Not supported" >&2

%/.exists:
	mkdir -p $(dir $@)

BUILD_DIR=_build

cross.test: ${BUILD_DIR}/.exists
	${OCAML_CROSS}ocaml --version
	${OCAML_CROSS}ocamlc -config
	rm -rf hello.cm? hello.o ${BUILD_DIR}/hello.bc ${BUILD_DIR}/hello.bin
	${OCAML_CROSS}ocaml hello.ml
	${OCAML_CROSS}ocamlc hello.ml -o ${BUILD_DIR}/hello.bc && ${OCAML_CROSS}ocamlrun ${BUILD_DIR}/hello.bc
	${OCAML_CROSS}ocamlc.byte hello.ml -o ${BUILD_DIR}/hello.bc && ${OCAML_CROSS}ocamlrun ${BUILD_DIR}/hello.bc
	${OCAML_CROSS}ocamlopt hello.ml -o ${BUILD_DIR}/hello.bin && file ${BUILD_DIR}/hello.bin && ${TARGET} ${BUILD_DIR}/hello.bin
	${OCAML_CROSS}ocamlopt.byte hello.ml -o ${BUILD_DIR}/hello.bin && file ${BUILD_DIR}/hello.bin && ${TARGET} ${BUILD_DIR}/hello.bin
