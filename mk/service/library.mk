$Sall: $Slibrary-all

.PHONY: $Slibrary-build
$Slibrary-all: $Slibrary-build

$Dlibrary/node_modules:
	cd $Dlibrary && npm ci

$Dcothority/proto.awk:
	git clone https://github.com/dedis/cothority $(@D)
cothority_protos := network onet skipchain
$Dprotobuf:; mkdir $@
$Dprotobuf/src.proto: $Dcothority/proto.awk | $Dsrc $Dprotobuf
	awk -f $< $Dsrc/lib/proto.go > $@

$Dlibrary/src/proto.json: | $Dlibrary/node_modules
$Dlibrary/src/proto.json: $Dprotobuf/src.proto $(foreach p,$(cothority_protos),$Dcothority/external/proto/$p.proto)
	PATH=$(PATH):$Dlibrary/node_modules/protobufjs/bin pbjs -t json -o $@ $^

.PHONY: $Slibrary-proto
$Slibrary-proto: $Dlibrary/src/proto.json
$Slibrary-build $Slibrary-test: $Slibrary-proto

.PHONY: $Slibrary-build
$Slibrary-build: | $Dlibrary/node_modules
	cd $Dlibrary && npm run build

.PHONY: $Slibrary-test
$Slibrary-test: | $Dlibrary/node_modules
	cd $Dlibrary && npm run test
