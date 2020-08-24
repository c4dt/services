$Sall: $Slibrary-all

.PHONY: $Slibrary-build
$Slibrary-all: $Slibrary-build

$Dlibrary/node_modules:
	cd $Dlibrary && npm ci

.PHONY: $Slibrary-build
$Slibrary-build: | $Dlibrary/node_modules
	cd $Dlibrary && npm run build

.PHONY: $Slibrary-test
$Slibrary-test: | $Dlibrary/node_modules
	cd $Dlibrary && npm run test
