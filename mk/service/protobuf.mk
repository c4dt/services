$Sall: $Sprotobuf-all

.PHONY: $Sprotobuf-build
$Sprotobuf-build: $Dprotobuf/proto.json

$Dprotobuf/node_modules/protobufjs/.installed:
	cd $Dprotobuf && npm i protobufjs
	touch $@
$Dprotobuf/node_modules/.bin/pbjs: | $Dprotobuf/node_modules/protobufjs/.installed
$Dprotobuf/node_modules/.bin/pbts: | $Dprotobuf/node_modules/protobufjs/.installed

$Dprotobuf/proto.json: | $Dprotobuf/node_modules/.bin/pbjs
	$Dprotobuf/node_modules/.bin/pbjs -t json -o $@ $^
$Dprotobuf/proto.js: | $Dprotobuf/node_modules/.bin/pbjs
	$Dprotobuf/node_modules/.bin/pbjs -t static-module -o $@ $^
$Dprotobuf/proto.d.ts: $Dprotobuf/proto.js | $Dprotobuf/node_modules/.bin/pbts
	$Dprotobuf/node_modules/.bin/pbts -o $@ $^

.PHONY: $Sprotobuf-all
$Sprotobuf-all: $Sprotobuf-build
