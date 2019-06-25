$Sall: $Sbackend-all
$Sserve: $Sbackend-serve

.PHONY: $Sbackend-all
$Sbackend-all: $Sbackend-build $Sbackend-test

.PHONY: $Sbackend-serve

ifneq ($(wildcard $Dprotobuf),)
$Sbackend-build $Sbackend-test: $Sbackend-proto

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
define $Swith-conodes-sh =
	nodes=''
	network=''
	trap 'echo $$nodes | xargs docker stop' EXIT INT
	ports=$$(for i in $(serve_backend_node-ids); do p=`$(call $Sbackend-port-ws,$$i)`; echo --publish=$$p:$$p; done) \

	for i in $(serve_backend_node-ids)
	do \
		n=$$(docker run --detach --rm --volume $(CURDIR)/$Dbackend/build/conode-$$i:/config \
			$$ports $$network \
			--env DEBUG_COLOR=true \
			c4dt/$(service)-backend:latest -d 4 -c /config/private.toml server)
		nodes="$$nodes $$n"
		if [ -z "$$network" ]
		then \
			network=--network=container:$$n
			ports=''
		fi
	done \

	for i in $(serve_backend_node-ids)
	do \
		port_ws=`$(call $Sbackend-port-ws,$$i)`
		while ! curl -s localhost:$$port_ws; do sleep 0.1; done
	done \

	$1
endef
# $1	shell script to wrap
$Swith-conodes = $(subst $($Swith-conodes-newline),;,$($Swith-conodes-sh))

$Dbackend/build/bcadmin: | $Dbackend/cothority $Dbackend/build
	cd $Dbackend/cothority/byzcoin/bcadmin && GO111MODULE=on go build -o ../../../build/$(@F)
$Dbackend/build/conodes.toml: $(foreach i,$(serve_backend_node-ids),$Dbackend/build/conode-$i/public.toml)
	for f in $^; do echo [[servers]]; sed -E 's,^[[:space:]]*\[(Services[^]]*)\]$$,[servers.\1],' $$f; done > $@

$Dbackend/build/conode-%/private.toml: private i = $(@D:$Dbackend/build/conode-%=%)
$Dbackend/build/conode-%/private.toml: $Dbackend/build/conode
	mkdir -p $(@D)
	$< --config $@ setup --non-interactive --host localhost --port `$(call $Sbackend-port-srv,$i)` --description conode-$i
$Dbackend/build/conode-%/public.toml: $Dbackend/build/conode-%/private.toml
	grep -E '^\s*((Address|Suite|Public|Description) = .*|\[Services[^]]*\])$$' $^ > $@
$Dbackend/build/ident: | $Sbackend-docker-build
$Dbackend/build/ident: $Dbackend/build/bcadmin $Dbackend/build/conodes.toml $(foreach i,$(serve_backend_node-ids),$Dbackend/build/conode-$i/private.toml)
	$(call $Swith-conodes, \
		$< -c $Dbackend/build create $(word 2,$^); \
		( $< latest --bc $Dbackend/build/bc-*; $< key -print $Dbackend/build/key-* ) > $@)

$Dbackend/build/conode.Linux.x86_64: $Dbackend/build/conode.go $Dbackend/build/main.go $Dbackend/*.go | $Dbackend/build
	cd $(@D) && GO111MODULE=on GOOS=linux GOARCH=amd64 go build -o ../build/$(@F)
.PHONY: $Sbackend-docker-build
$Sbackend-docker-build: $Dbackend/Dockerfile $Dbackend/build/conode.Linux.x86_64
	 docker build --tag c4dt/$(service)-backend:latest --file $< $(<D)

.PHONY: $Sbackend-build $Sbackend-docker-build
$Sbackend-build:
	cd $Dbackend && GO111MODULE=on go build

.PHONY: $Sbackend-test
$Sbackend-test:
	cd $Dbackend && GO111MODULE=on go test

$Sbackend-serve: $(foreach i,$(serve_backend_node-ids),$Dbackend/build/conode-$i/private.toml) | $Sbackend-docker-build
	$(call $Swith-conodes,sleep 999d)
