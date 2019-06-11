$Sall: $Swebserver-all
$Sserve: $Swebserver-serve

.PHONY: $Swebserver
$Swebserver-all: $Swebserver-build $Swebserver-test

$Dwebserver/node_modules:
	cd $Dwebserver && npm ci

ifneq ($(wildcard $Dprotobuf),)
# TODO for now, we can only generate for flat protobuf hierarchy
$Dwebserver/src/lib/proto.js: private PATH := $(PATH):$Dwebserver/node_modules/protobufjs/bin
$Dwebserver/src/lib/proto.js: $(foreach p,$($SPROTOS),$Dprotobuf/$p.proto) | $Dwebserver/node_modules
	pbjs -t static-module -o $@ $^
$Dwebserver/src/lib/proto.d.ts: private PATH := $(PATH):$Dwebserver/node_modules/protobufjs/bin
$Dwebserver/src/lib/proto.d.ts: $Dwebserver/src/lib/proto.js | $Dwebserver/node_modules
	pbts -o $@ $<

.PHONY: $Swebserver-proto
$Swebserver-proto: $Dwebserver/src/lib/proto.js $Dwebserver/src/lib/proto.d.ts
$Swebserver-build $Swebserver-test $Swebserver-serve: $Swebserver-proto
endif

ifneq ($(wildcard $Dbackend),)
$Dwebserver/src/assets/conodes.toml: $Dbackend/build/conodes.toml
	cp $^ $@
$Dwebserver/src/config.ts: $Dbackend/build/ident
	awk '	function mkvar(key,value) { \
			print "export const " key " = Buffer.from(\"" value "\", \"hex\");" \
		} \
		/^ByzCoinID:/	{mkvar("ByzCoinID", $$2)} \
		/^Admin DARC:/	{mkvar("AdminDarc", $$3)} \
		/^Private:/	{mkvar("Ephemeral", $$2)}' $^ > $@

$Swebserver-build $Swebserver-test $Swebserver-serve: $Dwebserver/src/config.ts $Dwebserver/src/assets/conodes.toml
endif

.PHONY: $Swebserver-build
$Swebserver-build: private PATH := $(PATH):node_modules/@angular/cli/bin
$Swebserver-build: | $Dwebserver/node_modules
	cd $Dwebserver && ng build

.PHONY: $Swebserver-test
$Swebserver-test: private PATH := $(PATH):node_modules/@angular/cli/bin
$Swebserver-test: | $Dwebserver/node_modules
	cd $Dwebserver && ng test

.PHONY: $Swebserver-serve
$Swebserver-serve: private PATH := $(PATH):node_modules/@angular/cli/bin
$Swebserver-serve: | $Dwebserver/node_modules
	cd $Dwebserver && ng serve
