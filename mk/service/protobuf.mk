PROTOBUF_VERSION := 6.11.2

$Sall: $Sprotobuf-all

.PHONY: $Sprotobuf-build
$Sprotobuf-build: $Dprotobuf/proto.json

$Dprotobuf/proto.json:
	npx -p protobufjs@$(PROTOBUF_VERSION) pbjs -t json -o $@ $^
$Dprotobuf/proto.js:
	npx -p protobufjs@$(PROTOBUF_VERSION) pbjs -t static-module -o $@ $^
$Dprotobuf/proto.d.ts: $Dprotobuf/proto.js
	npx -p protobufjs@$(PROTOBUF_VERSION) pbts -o $@ $^

.PHONY: $Sprotobuf-all
$Sprotobuf-all: $Sprotobuf-build
