$Sall: $Swebapp-all
$Sserve: $Swebapp-serve

.PHONY: $Swebapp-all
$Swebapp-all: $Swebapp-build $Swebapp-test

$Dwebapp/node_modules:
	cd $Dwebapp && npm ci

ifneq ($(wildcard $Dprotobuf),)
# TODO for now, we can only generate for flat protobuf hierarchy
$Dwebapp/src/lib/proto.js: private PATH := $(PATH):$Dwebapp/node_modules/protobufjs/bin
$Dwebapp/src/lib/proto.js: $(foreach p,$($SPROTOS),$Dprotobuf/$p.proto) | $Dwebapp/node_modules
	pbjs -t static-module -o $@ $^
$Dwebapp/src/lib/proto.d.ts: private PATH := $(PATH):$Dwebapp/node_modules/protobufjs/bin
$Dwebapp/src/lib/proto.d.ts: $Dwebapp/src/lib/proto.js | $Dwebapp/node_modules
	pbts -o $@ $<

.PHONY: $Swebapp-proto
$Swebapp-proto: $Dwebapp/src/lib/proto.js $Dwebapp/src/lib/proto.d.ts
$Swebapp-build $Swebapp-test $Swebapp-serve: $Swebapp-proto
endif

ifneq ($(wildcard $Dbackend),)
$Dwebapp/src/assets/$(toml_filename): $Dbackend/build/conodes.toml
	cp $^ $@
$Dwebapp/src/config.ts: $Dbackend/build/ident
	awk '	function mkvar(key,value) { \
			print "export const " key " = Buffer.from(\"" value "\", \"hex\");" \
		} \
		/^ByzCoinID:/	{mkvar("ByzCoinID", $$2)} \
		/^Admin DARC:/	{mkvar("AdminDarc", $$3)} \
		/^Private:/	{mkvar("Ephemeral", $$2)}' $^ > $@

$Swebapp-build $Swebapp-test $Swebapp-serve: $Dwebapp/src/config.ts $Dwebapp/src/assets/$(toml_filename)
endif

.PHONY: $Swebapp-build
$Swebapp-build: | $Dwebapp/node_modules
	cd $Dwebapp && npx ng build --prod

.PHONY: $Swebapp-test
$Swebapp-test: | $Dwebapp/node_modules
	cd $Dwebapp && npx ng test --watch=false

.PHONY: $Swebapp-serve
$Swebapp-serve: | $Dwebapp/node_modules
	cd $Dwebapp && npx ng serve --aot
