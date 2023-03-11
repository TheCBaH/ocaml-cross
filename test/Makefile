
all:
	echo "Not supported" >&2

%/.exists:
	mkdir -p $(dir $@)

BUILD=_build

cross.test: ${BUILD}/.exists
	${OCAML_CROSS}ocaml --version
	${OCAML_CROSS}ocamlc -config
	rm -rf hello.cm? hello.o ${BUILD}/hello.bc ${BUILD}/hello.bin
	${OCAML_CROSS}ocaml hello.ml
	${OCAML_CROSS}ocamlc hello.ml -o ${BUILD}/hello.bc && ${OCAML_CROSS}ocamlrun ${BUILD}/hello.bc
	${OCAML_CROSS}ocamlc.byte hello.ml -o ${BUILD}/hello.bc && ${OCAML_CROSS}ocamlrun ${BUILD}/hello.bc
	${OCAML_CROSS}ocamlopt hello.ml -o ${BUILD}/hello.bin && file ${BUILD}/hello.bin && ${TARGET} ${BUILD}/hello.bin
	${OCAML_CROSS}ocamlopt.byte hello.ml -o ${BUILD}/hello.bin && file ${BUILD}/hello.bin && ${TARGET} ${BUILD}/hello.bin
