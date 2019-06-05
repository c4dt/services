$Sall: $Sbackend-all
$Sserve: $Sbackend-serve

.PHONY: $Sbackend-all
$Sbackend-all: $Sbackend-build $Sbackend-test

.PHONY: $Sbackend-serve

ifneq ($(wildcard $Dprotobuf),)
$Sbackend-build: $Sbackend-proto

ifndef GOPATH
GOPATH := $(shell go env GOPATH)
endif

$(GOPATH)/bin/protoc-gen-go:
	go get github.com/golang/protobuf/protoc-gen-go

# $1	proto pkg
define $Sbackend-proto =
$Dbackend/proto/$1/$1.pb.go: private PATH := $(PATH):$(GOPATH)/bin
$Dbackend/proto/$1/$1.pb.go: $Dprotobuf/$1.proto | $(GOPATH)/bin/protoc-gen-go
	mkdir -p $$(@D)
	cd $Dprotobuf && protoc --go_out=../$$(@D) $$(^F)
endef
$(foreach p,$($SPROTOS),$(eval $(call $Sbackend-proto,$p)))

# TODO for now, we can only generate for flat protobuf hierarchy
.PHONY: $Sbackend-proto
private $Sbackend-proto-deps := $(foreach p,$($SPROTOS),$Dbackend/proto/$p/$p.pb.go)
$Sbackend-proto: $($Sbackend-proto-deps)
$Dbackend/build/conode: $($Sbackend-proto-deps)
$Dbackend/build/conode.Linux.x86_64: $($Sbackend-proto-deps)
endif

$Dbackend/build:
	mkdir $@
$Dbackend/cothority:
	git clone https://github.com/c4dt/cothority $@
$Dbackend/build/conode.go: | $Dbackend/cothority $Dbackend/build
	cp $Dbackend/cothority/conode/conode.go $@
$Dbackend/build/main.go: | $Dbackend/build
	echo package main					> $@
	echo import _ \"github.com/c4dt/$(service)/backend\"	>> $@
$Dbackend/build/conode: $Dbackend/build/conode.go $Dbackend/build/main.go $Dbackend/*.go
	cd $(@D) && GO111MODULE=on go build -o ../build/$(@F)

$Sbackend-port-srv = expr 7770 + $1 '*' 2
$Sbackend-port-ws = $(call $Sbackend-port-srv,$1) + 1
define $Swith-conodes-newline =


endef
define $Swith-conodes-network =
	[ -z "$$(docker network ls --filter name=$Sbackend | tail -n+2)" ] && \
		docker network create $Sbackend; \
	docker network inspect backend | awk -F \" '/"Gateway"/ {print $$4}'
endef
define $Swith-conodes-sh =
	gateway=`$($Swith-conodes-network)`
	nodes='' \

	for i in $(serve_backend_node-ids)
	do \
		port_srv=`$(call $Sbackend-port-srv,$$i)`
		port_ws=`$(call $Sbackend-port-ws,$$i)`
		docker run --rm --volume $(CURDIR)/$Dbackend/build/conode-$$i:/config \
			--network $Sbackend \
			--publish $$port_srv:$$port_srv --publish $$port_ws:$$port_ws \
			c4dt/$(service)-backend:latest -c /config/private.toml server & \
		nodes="$$nodes $$!"
	done \

	for i in $(serve_backend_node-ids)
	do \
		port_ws=`$(call $Sbackend-port-ws,$$i)`
		while ! curl -s $$gateway:$$port_ws; do sleep 0.1; done
	done \

	$1 \

	kill $$nodes
	wait $$nodes || :;
endef
# $1	shell script to wrap
$Swith-conodes = $(subst $($Swith-conodes-newline),;,$($Swith-conodes-sh))

$Dbackend/build/bcadmin: | $Dbackend/cothority $Dbackend/build
	cd $Dbackend/cothority/byzcoin/bcadmin && GO111MODULE=on go build -o ../../../build/$(@F)
$Dbackend/build/conodes.toml: $(foreach i,$(serve_backend_node-ids),$Dbackend/build/conode-$i/public.toml)
	for f in $^; do echo [[servers]]; sed -E 's,^\s*\[(Services[^]]*)\]$$,[servers.\1],' $$f; done > $@
$Dbackend/build/bc-vars: $Dbackend/build/bcadmin $Dbackend/build/conodes.toml $(foreach i,$(serve_backend_node-ids),$Dbackend/build/conode-$i/private.toml) | $Sbackend-docker-build
	$(call $Swith-conodes, ( \
		$< -c $Dbackend/build create $(word 2,$^); \
		$< latest --bc $Dbackend/build/bc-*; \
		$< key -print $Dbackend/build/key-* ) | \
		grep -E '^(ByzCoinID|Admin DARC|Private):' > $@)

$Dbackend/build/conode-%/private.toml: private i = $(@D:$Dbackend/build/conode-%=%)
$Dbackend/build/conode-%/private.toml: $Dbackend/build/conode
	mkdir -p $(@D)
	$< --config $@ setup --non-interactive --host localhost --port `$(call $Sbackend-port-srv,$i)` --description conode-$i
$Dbackend/build/conode-%/public.toml: $Dbackend/build/conode-%/private.toml
	grep -E '^\s*((Address|Suite|Public|Description) = .*|\[Services[^]]*\])$$' $^ > $@

$Dbackend/build/conode.Linux.x86_64: $Dbackend/build/conode.go $Dbackend/build/main.go $Dbackend/*.go | $Dbackend/build
	cd $(@D) && GO111MODULE=on GOOS=linux GOARCH=amd64 go build -o ../build/$(@F)
.PHONY: $Sbackend-docker-build
$Sbackend-docker-build: $Dbackend/Dockerfile $Dbackend/build/conode.Linux.x86_64
	 docker build --tag c4dt/$(service)-backend:latest --file $< $(<D)

.PHONY: $Sbackend-build
$Sbackend-build:
	cd $Dbackend && GO111MODULE=on go build

.PHONY: $Sbackend-test
$Sbackend-test:
	cd $Dbackend && GO111MODULE=on go test

$Sbackend-serve: $(foreach i,$(serve_backend_node-ids),$Dbackend/build/conode-$i/private.toml) | $Sbackend-docker-build
	$(call $Swith-conodes,sleep inf)
