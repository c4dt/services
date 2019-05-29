$Sall: $Sbackend-all
$Sserve: $Sbackend-docker-run

.PHONY: $Sbackend-all
$Sbackend-all: $Sbackend-build $Sbackend-test

.PHONY: $Sbackend-serve
$Sbackend-serve: $Sbackend-docker-run

ifneq ($(wildcard $Dprotobuf),)
$Sbackend-build: $Sbackend-proto

ifndef GOPATH
GOPATH := $(shell go env GOPATH)
endif

$(GOPATH)/bin/protoc-gen-go:
	go get github.com/golang/protobuf/protoc-gen-go

# $1	proto pkg
define backend-proto =
$Dbackend/proto/$1/$1.pb.go: private PATH := $(PATH):$(GOPATH)/bin
$Dbackend/proto/$1/$1.pb.go: $Dprotobuf/$1.proto | $(GOPATH)/bin/protoc-gen-go
	mkdir -p $$(@D)
	cd $Dprotobuf && protoc --go_out=../$$(@D) $$(^F)
endef
$(foreach p,$($SPROTOS),$(eval $(call backend-proto,$p)))

# TODO for now, we can only generate for flat protobuf hierarchy
.PHONY: $Sbackend-proto
$Sbackend-proto: $(foreach p,$($SPROTOS),$Dbackend/proto/$p/$p.pb.go)
endif

$Dbackend/cothority_template:
	git clone https://github.com/dedis/cothority_template $@
	# TODO not very indempotent
	#echo 'replace github.com/c4dt/$(service)/backend => ../' >> $@/go.mod
	cp $Dbackend/go.mod $Dbackend/cothority_template/conode
$Dbackend/cothority_template/conode/main.go: | $Dbackend/cothority_template
	echo package main					> $@
	#echo import _ \"github.com/c4dt/$(service)/backend\"	>> $@
$Dbackend/cothority_template/conode/conode: $Dbackend/*.go | $Dbackend/cothority_template/conode/main.go
	cd $(@D) && GO111MODULE=on go build -o $(@F)
$Dbackend/cothority_template/conode/conode_data/private.toml: $Dbackend/cothority_template/conode/conode
	( echo localhost:7770; echo; echo $(@D); echo; echo ) | $< setup
$Dbackend/cothority_template/conode/exe/conode.Linux.x86_64: $Dbackend/*.go | $Dbackend/cothority_template/conode/main.go
	mkdir -p $(@D)
	cd $(@D) && GO111MODULE=on GOOS=linux GOARCH=amd64 go build -o $(@F) ..
.PHONY: $Sbackend-docker-build
$Sbackend-docker-build: private dockerfile := backend/cothority_template/conode/Dockerfile-dev
$Sbackend-docker-build: $Dbackend/cothority_template/conode/exe/conode.Linux.x86_64
	 docker build --tag c4dt/$(service)-backend:latest --file $(dockerfile) $(dir $(dockerfile))
.PHONY: $Sbackend-docker-run
$Sbackend-docker-run: | $Sbackend-docker-build $Dbackend/cothority_template/conode/conode_data/private.toml
	docker run --rm --publish 7770-7771:7770-7771 \
		--volume $(CURDIR)/$Dbackend/cothority_template/conode/conode_data:/conode_data \
		c4dt/$(service)-backend:latest

.PHONY: $Sbackend-build
$Sbackend-build:
	cd $Dbackend && GO111MODULE=on go build

.PHONY: $Sbackend-test
$Sbackend-test:
	cd $Dbackend && GO111MODULE=on go test
