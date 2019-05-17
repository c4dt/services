ifeq ($(words $(MAKEFILE_LIST)),1)
$(error do not run directly, include it into a service)
endif

private self := $(lastword $(MAKEFILE_LIST))
private parent := $(word $(shell expr $(words $(MAKEFILE_LIST)) - 1),$(MAKEFILE_LIST))
D := $(dir $(parent))
ifndef S
S := $(lastword $(subst /, ,$(abspath $(dir $(parent)))))-
endif

.PHONY: $Sall

ifneq ($(wildcard $Dprotobuf),)
$SPROTOS := $(patsubst $Dprotobuf/%.proto,%,$(shell find $Dprotobuf -name '*.proto'))
endif

ifneq ($(wildcard $Dconode),)
include $(dir $(self))service/conode.mk
endif
