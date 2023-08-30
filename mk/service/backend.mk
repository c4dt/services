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
TESTNET_NET := 10.7.7
TESTNET_SUB := $(TESTNET_NET).0/24

$(GOPATH)/bin/protoc-gen-go:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest

# $1	proto pkg
define $Sbackend-proto =
$Dbackend/proto/$1/$1.pb.go: private PATH := $(PATH):$(GOPATH)/bin
$Dbackend/proto/$1/$1.pb.go: $Dprotobuf/$1.proto | $(GOPATH)/bin/protoc-gen-go
	mkdir -p $$(@D)
	cd $Dprotobuf && protoc --go_out=../$$(@D) --go_opt=paths=source_relative $$(^F)
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
$Dbackend/configs:
	mkdir $@
$Dbackend/cothority:
	git clone https://github.com/dedis/cothority.git --depth 1 $@
$Dbackend/build/conode.go: | $Dbackend/cothority $Dbackend/build
	cp $Dbackend/cothority/conode/conode.go $@
$Dbackend/build/main.go: | $Dbackend/build
	echo package main					> $@
	echo import _ \"github.com/c4dt/$(service)/backend\"	>> $@
$Dbackend/build/go.mod: | $Sbackend-proto $Dbackend/build/main.go $Dbackend/build
	cd $Dbackend/build && go mod init github.com/dedis/cothority
	echo 'replace github.com/c4dt/service-stainless/backend => ../' >> $@
	cd $Dbackend/build && go mod tidy
$Dbackend/build/conode: $Dbackend/build/conode.go $Dbackend/build/main.go $Dbackend/build/go.mod $Dbackend/*.go
	cd $(@D) && GO111MODULE=on go build -o ./$(@F)

$Sbackend-port-srv = expr 7770 + $1 '*' 2
$Sbackend-port-ws = $(call $Sbackend-port-srv,$1) + 1
define $Swith-conodes-newline =


endef

define $Swith-conodes-sh =
	nodes=''
	if [ -z "$2" ]; then trap 'echo $$nodes | xargs docker stop; docker network rm testnet' EXIT INT; fi
	ports=$$(for i in $(serve_backend_node-ids); do p=`$(call $Sbackend-port-ws,$$i)`; echo --publish=$$p:$$p; done) \

	docker network ls | grep testnet && docker network rm testnet; \
	docker network create --subnet=$(TESTNET_SUB) testnet \

	for i in $(serve_backend_node-ids)
	do \
		ports=$$(( 7770 + $$i * 2 )); \
		ports="$$ports-$$(( $$ports + 1 ))"; \
		n=$$( docker run --detach --rm \
			--env CONODE_SERVICE_PATH=/config \
			--volume $(CURDIR)/$Dbackend/configs/conode-$$i:/config \
            --user `id -u`:`id -g` \
			--publish=$$ports:$$ports \
			--env DEBUG_COLOR=true \
			--network=testnet \
			--name "conode-stainless-$$i" \
			c4dt/$(service)-backend:latest -d 2 -c /config/private.toml server )
		nodes="$$nodes $$n"
	done \

	for i in $(serve_backend_node-ids)
	do \
		port_ws=`$(call $Sbackend-port-ws,$$i)`
		while ! curl -s localhost:$$port_ws > /dev/null; do sleep 0.1; done
	done \
	
	$1
endef
# $1	shell script to wrap
$Swith-conodes = $(subst $($Swith-conodes-newline),;,$($Swith-conodes-sh))

$Dbackend/build/bcadmin: | $Dbackend/cothority $Dbackend/build
	cd $Dbackend/cothority/byzcoin/bcadmin && GO111MODULE=on go build -o ../../../build/$(@F)
$Dbackend/configs/conodes.toml: $(foreach i,$(serve_backend_node-ids),$Dbackend/configs/conode-$i/public.toml)
	for f in $^; do echo [[servers]]; sed -E 's,^[[:space:]]*\[(Services[^]]*)\]$$,[servers.\1],' $$f; done > $@

$Dbackend/configs/conode-%/private.toml: private i = $(@D:$Dbackend/configs/conode-%=%)
$Dbackend/configs/conode-%/private.toml: $Dbackend/build/conode
	mkdir -p $(@D)
	$< --config $@ setup --non-interactive --host $(TESTNET_NET).$$(( $i + 1 )) --port `$(call $Sbackend-port-srv,$i)` --description conode-$i
$Dbackend/configs/conode-%/public.toml: $Dbackend/configs/conode-%/private.toml
	grep -E '^\s*((Address|Suite|Public|Description) = .*|\[Services[^]]*\])$$' $^ > $@
	echo "URL = \"http://localhost:$$(( $$(grep Address $@ | sed -e 's/.*:\(.*\)./\1/') + 1 ))\"\n$$( cat $@ )" > $@
$Dbackend/configs/ident: | $Sbackend-docker-build
$Dbackend/configs/ident: $Dbackend/build/bcadmin $Dbackend/configs/conodes.toml $(foreach i,$(serve_backend_node-ids),$Dbackend/configs/conode-$i/private.toml)
	$(call $Swith-conodes, \
		$< -c $Dbackend/configs create $(word 2,$^); \
		( $< latest --bc $Dbackend/configs/bc-*; $< key -print $Dbackend/configs/key-* ) > $@)

$Dbackend/build/conode.Linux.x86_64: $Dbackend/build/conode.go $Dbackend/build/main.go $Dbackend/*.go | $Dbackend/build
	cd $(@D) && GO111MODULE=on GOOS=linux GOARCH=amd64 go build -o ./$(@F)
.PHONY: $Sbackend-docker-build
$Sbackend-docker-build: $Dbackend/Dockerfile $Dbackend/build/conode.Linux.x86_64
	 docker build --tag c4dt/$(service)-backend:latest --file $< $(<D)

.PHONY: $Sbackend-build $Sbackend-docker-build
$Sbackend-build:
	cd $Dbackend && GO111MODULE=on go build

.PHONY: $Sbackend-test
$Sbackend-test:
	cd $Dbackend 

$Sbackend-serve: $(foreach i,$(serve_backend_node-ids),$Dbackend/configs/conode-$i/private.toml) | $Sbackend-docker-build
	$(call $Swith-conodes,sleep 999d)

$Sbackend-serve-test: $(foreach i,$(serve_backend_node-ids),$Dbackend/configs/conode-$i/private.toml) | $Sbackend-docker-build
	$(call $Swith-conodes,echo "ready", NOTRAP)
