# define some useful variables
#   D		root directory of service
#   S		service prefix for rules
#   service	service name
#   SERVICE	service name, upper-case, s/-/_/g
#   $SPROTOS	proto packages name

ifeq ($(words $(MAKEFILE_LIST)),1)
$(error do not run directly, include it into a service)
endif

private self := $(lastword $(MAKEFILE_LIST))
private parent := $(word $(shell expr $(words $(MAKEFILE_LIST)) - 1),$(MAKEFILE_LIST))
D := $(dir $(parent))
ifndef service
service := $(lastword $(subst /, ,$(abspath $(dir $(parent)))))
endif
SERVICE := $(shell echo $(service) | tr -- -[:lower:] _[:upper:])
# if launched by root of service
ifneq ($(words $(MAKEFILE_LIST)),2)
S := $(service)-
endif

.PHONY: $Sall

$Dsrc:
	git clone https://github.com/c4dt/$(service:service-%=%) $@

ifneq ($(wildcard $Dprotobuf),)
$SPROTOS := $(patsubst $Dprotobuf/%.proto,%,$(shell find $Dprotobuf -name '*.proto'))
endif

ifneq ($(wildcard $Dconode),)
include $(dir $(self))service/conode.mk
endif

ifneq ($(wildcard $Dwebserver),)
include $(dir $(self))service/webserver.mk
endif
