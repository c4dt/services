$Sall: $Swebserver

.PHONY: $Swebserver
$Swebserver: $Swebserver-build $Swebserver-test

ifneq ($(wildcard $Dprotobuf),)
$Swebserver-build: $Swebserver-proto

$Dwebserver/node_modules:
	cd $Dwebserver && npm ci

# TODO for now, we can only generate for flat protobuf hierarchy
$Dwebserver/src/lib/proto.js: private PATH := $(PATH):$Dwebserver/node_modules/protobufjs/bin
$Dwebserver/src/lib/proto.js: $(foreach p,$($SPROTOS),$Dprotobuf/$p.proto) | $Dwebserver/node_modules
	pbjs -t static-module -o $@ $^
$Dwebserver/src/lib/proto.d.ts: private PATH := $(PATH):$Dwebserver/node_modules/protobufjs/bin
$Dwebserver/src/lib/proto.d.ts: $Dwebserver/src/lib/proto.js | $Dwebserver/node_modules
	pbts -o $@ $<

.PHONY: $Swebserver-proto
$Swebserver-proto: $Dwebserver/src/lib/proto.js $Dwebserver/src/lib/proto.d.ts
$Swebserver-build: $Swebserver-proto
$Swebserver-test: $Swebserver-proto
endif

.PHONY: $Swebserver-build
$Swebserver-build: private PATH := $(PATH):node_modules/@angular/cli/bin
$Swebserver-build: | $Dwebserver/node_modules
	cd $Dwebserver && ng build

.PHONY: $Swebserver-test
$Swebserver-test: private PATH := $(PATH):node_modules/@angular/cli/bin
$Swebserver-test: | $Dwebserver/node_modules
	cd $Dwebserver && ng test
