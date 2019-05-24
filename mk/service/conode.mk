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

$Dconode/cothority_template:
	git clone https://github.com/dedis/cothority_template $@
	# TODO not very indempotent
	echo 'replace github.com/c4dt/$(service)/conode => ../' >> $@/go.mod
$Dconode/cothority_template/conode/main.go: | $Dconode/cothority_template
	echo package main					> $@
	echo import _ \"github.com/c4dt/$(service)/conode\"	>> $@
$Dconode/cothority_template/conode/conode: $Dconode/*.go | $Dconode/cothority_template/conode/main.go
	cd $(dir $@) && GO111MODULE=on GOOS=linux GOARCH=amd64 go build -o $(notdir $@)
$Dconode/cothority_template/conode/conode_data/private.toml: $Dconode/cothority_template/conode/conode
	( echo localhost:7770; echo; echo $(dir $@); echo; echo ) | $< setup
$Dconode/cothority_template/conode/exe/conode.Linux.x86_64: $Dconode/cothority_template/conode/main.go
	mkdir -p $(dir $@)
	cp $^ $@
.PHONY: $Sconode-docker-build
$Sconode-docker-build: $Dconode/cothority_template/conode/Dockerfile-dev | $Dconode/cothority_template/conode/exe/conode.Linux.x86_64
	 docker build --tag c4dt/$(service)-conode:latest --file $< $(dir $<)
.PHONY: $Sconode-docker-run
$Sconode-docker-run: | $Sconode-docker-build $Dconode/cothority_template/conode/conode_data/private.toml
	docker run --rm --publish 7770-7771:7770-7771 \
		--volume $(CURDIR)/$Dconode/cothority_template/conode/conode_data:/conode_data \
		c4dt/$(service)-conode:latest

.PHONY: $Sconode-build
$Sconode-build:
	cd $Dconode && GO111MODULE=on go build

.PHONY: $Sconode-test
$Sconode-test:
	cd $Dconode && GO111MODULE=on go test
