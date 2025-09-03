# Cross-platform docker image cleanup
# Usage examples:
#   make docker-clean                     # remove images not used by containers
#   make docker-clean FORCE=1             # also remove containers using these images
#   make docker-clean FORCE=1 PRUNE=1     # also prune dangling layers
#   make docker-clean INCLUDE_K8S=1       # include Kubernetes images
#   make docker-clean DRY=1               # dry run

OS ?= $(OS)
POWERSHELL := powershell -NoProfile -ExecutionPolicy Bypass

define PS_FLAGS
$(if $(filter 1,$(FORCE)),-ForceRemoveContainers,)
$(if $(filter 1,$(PRUNE)),-PruneDangling,)
$(if $(filter 1,$(INCLUDE_K8S)),-IncludeK8s,)
$(if $(filter 1,$(DRY)),-DryRun,)
endef

.PHONY: docker-clean
docker-clean:
ifeq ($(OS),Windows_NT)
	$(POWERSHELL) -File scripts/remove-images.ps1 $(PS_FLAGS)
else
	DRY=$(DRY) FORCE=$(FORCE) PRUNE=$(PRUNE) INCLUDE_K8S=$(INCLUDE_K8S) bash scripts/remove-images.sh
endif

