$Sall: $Sconode

.PHONY: $Sconode
$Sconode: $Sconode-build $Sconode-test

ifneq ($(wildcard $Dprotobuf),)
$Sconode-build: $Sconode-proto

$(GOPATH)/bin/protoc-gen-go:
	go get github.com/golang/protobuf/protoc-gen-go

# $1	proto pkg
define conode-proto =
$Dconode/proto/$1/$1.pb.go: private PATH := $$(PATH):$$(GOPATH)/bin
$Dconode/proto/$1/$1.pb.go: $Dprotobuf/$1.proto | $$(GOPATH)/bin/protoc-gen-go
	TODO? mkdir -p $(dir $@)
	cd $Dprotobuf && protoc --go_out=../$$(dir $$@) $$(notdir $$^)
endef
$(foreach p,$($SPROTOS),$(call conode-proto,$p))

# TODO for now, we can only generate for flat protobuf hierarchy
.PHONY: $Sconode-proto
$Sconode-proto: $(foreach p,$($SPROTOS),$(realpath $Dconode/proto/$p/$p.pb.go))
endif

.PHONY: $Sconode-build
$Sconode-build:
	cd $Dconode && GO111MODULE=on go build

.PHONY: $Sconode-test
$Sconode-test:
	cd $Dconode && GO111MODULE=on go test
