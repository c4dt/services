$Sall: $Sprotobuf-all

.PHONY: $Sprotobuf-build
$Sprotobuf-build: $Dprotobuf/proto.json

$Dprotobuf/node_modules/protobufjs/.installed:
	cd $Dprotobuf && npm i protobufjs
	touch $@
$Dprotobuf/node_modules/.bin/pbjs: | $Dprotobuf/node_modules/protobufjs/.installed
$Dprotobuf/node_modules/.bin/pbts: | $Dprotobuf/node_modules/protobufjs/.installed

$Dprotobuf/proto.json: PATH := $(PATH):$Dprotobuf/node_modules/.bin
$Dprotobuf/proto.json: | $Dprotobuf/node_modules/.bin/pbjs
	pbjs -t json -o $@ $^
$Dprotobuf/proto.js: PATH := $(PATH):$Dprotobuf/node_modules/.bin
$Dprotobuf/proto.js: | $Dprotobuf/node_modules/.bin/pbjs
	pbjs -t static-module -o $@ $^
$Dprotobuf/proto.d.ts: PATH := $(PATH):$Dprotobuf/node_modules/.bin
$Dprotobuf/proto.d.ts: $Dprotobuf/proto.js | $Dprotobuf/node_modules/.bin/pbts
	pbts -o $@ $^

.PHONY: $Sprotobuf-all
$Sprotobuf-all: $Sprotobuf-build
