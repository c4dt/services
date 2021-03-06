# define some targets
#   all		build and test everything
#   serve	run server parts
# define some useful variables
#   D		root directory of service
#   S		service prefix for rules
#   service	service name
#   SERVICE	service name, upper-case, s/-/_/g

ifeq ($(words $(MAKEFILE_LIST)),1)
$(error do not run directly, include it into a service)
endif

self := $(lastword $(MAKEFILE_LIST))
parent := $(word $(shell expr $(words $(MAKEFILE_LIST)) - 1),$(MAKEFILE_LIST))
D := $(dir $(parent))
ifeq ($D,./)
D :=
endif
ifndef service
service := $(lastword $(subst /, ,$(abspath $(dir $(parent)))))
endif
SERVICE := $(shell echo $(service) | tr -- -[:lower:] _[:upper:])
# if launched by root of service
ifneq ($(words $(MAKEFILE_LIST)),2)
S := $(service)-
endif

.PHONY: $Sall $Sserve

$Dsrc:
	git clone https://github.com/c4dt/$(service:service-%=%) $@

include $(dir $(self))/config.mk

ifneq ($(wildcard $Dprotobuf),)
include $(dir $(self))service/protobuf.mk
endif

ifneq ($(wildcard $Dbackend),)
include $(dir $(self))service/backend.mk
endif

ifneq ($(wildcard $Dlibrary),)
include $(dir $(self))service/library.mk
endif

ifneq ($(wildcard $Dwebapp),)
include $(dir $(self))service/webapp.mk
endif
