$Sall: $Swebapp-all
$Sserve: $Swebapp-serve

.PHONY: $Swebapp
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
$Dwebapp/src/assets/config.toml: $Dbackend/build/ident
	awk '\
		/^ByzCoinID:/	{printf("ByzCoinID = \"%s\"\n", $$2)} \
		/^Admin DARC:/	{printf("AdminDarc = \"%s\"\n", $$3)} \
		/^Private:/		{printf("Ephemeral = \"%s\"\n", $$2)} \
		' $^ > $@

$Swebapp-build $Swebapp-test $Swebapp-serve: $Dwebapp/src/assets/config.toml $Dwebapp/src/assets/$(toml_filename)
endif

.PHONY: $Swebapp-build
$Swebapp-build: private PATH := $(PATH):node_modules/@angular/cli/bin
$Swebapp-build: | $Dwebapp/node_modules
	cd $Dwebapp && ng build $(webapp_build_options)

.PHONY: $Swebapp-test
$Swebapp-test: private PATH := $(PATH):node_modules/@angular/cli/bin
$Swebapp-test: | $Dwebapp/node_modules
	cd $Dwebapp && ng test --watch=false

.PHONY: $Swebapp-serve
$Swebapp-serve: private PATH := $(PATH):node_modules/@angular/cli/bin
$Swebapp-serve: | $Dwebapp/node_modules
	cd $Dwebapp && ng serve --aot
