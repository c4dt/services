$Sall: $Sprotobuf-all

.PHONY: $Sprotobuf-build
$Sprotobuf-build: $Dprotobuf/proto.json

$Dprotobuf/node_modules/bin/pbjs:
	cd $Dprotobuf && npm i protobufjs
$Dprotobuf/proto.json: PATH := $(PATH):$Dprotobuf/node_modules/.bin
$Dprotobuf/proto.json: | $Dprotobuf/node_modules/bin/pbjs
	pbjs -t json -o $@ $^

.PHONY: $Sprotobuf-all
$Sprotobuf-all: $Sprotobuf-build
