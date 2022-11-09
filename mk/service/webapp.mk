$Sall: $Swebapp-all
$Sserve: $Swebapp-serve

.PHONY: $Swebapp-all
$Swebapp-all: $Swebapp-build

$Dwebapp/node_modules/.installed:
	cd $Dwebapp && npm ci
	touch $@

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

$Swebapp-build $Swebapp-serve: $Dwebapp/src/config.ts $Dwebapp/src/assets/$(toml_filename)
endif

.PHONY: $Swebapp-build
$Swebapp-build: | $Dwebapp/node_modules/.installed
	cd $Dwebapp && npx ng build --configuration production

ifneq ($(shell find webapp -name '*.spec.ts'),)
.PHONY: $Swebapp-test
$Swebapp-test: | $Dwebapp/node_modules/.installed
	cd $Dwebapp && npx ng test --watch=false

ifneq ($(wildcard $Dbackend),)
$Swebapp-test: $Dwebapp/src/config.ts $Dwebapp/src/assets/$(toml_filename)
endif

$Swebapp-all: $Swebapp-test
endif

.PHONY: $Swebapp-serve
$Swebapp-serve: | $Dwebapp/node_modules/.installed
	cd $Dwebapp && npx ng serve --aot
