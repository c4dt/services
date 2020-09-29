$Sall: $Sprotobuf-all

.PHONY: $Sprotobuf-build
$Sprotobuf-build: $Dprotobuf/proto.json

$Dprotobuf/proto.json:
	npx -p protobufjs pbjs -t json -o $@ $^
$Dprotobuf/proto.js:
	npx -p protobufjs pbjs -t static-module -o $@ $^
$Dprotobuf/proto.d.ts: $Dprotobuf/proto.js
	npx -p protobufjs pbts -o $@ $^

.PHONY: $Sprotobuf-all
$Sprotobuf-all: $Sprotobuf-build
