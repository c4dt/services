$Sall: $Slibrary-all

.PHONY: $Slibrary-build
$Slibrary-all: $Slibrary-build

$Dlibrary/node_modules/.installed:
	cd $Dlibrary && npm ci
	touch $@

.PHONY: $Slibrary-build
$Slibrary-build: | $Dlibrary/node_modules/.installed
	cd $Dlibrary && npm run build

.PHONY: $Slibrary-test
$Slibrary-test: | $Dlibrary/node_modules/.installed
	cd $Dlibrary && npm run test
