SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
ARCH=
ifeq ($(UNAME_M), x86_64)
	ARCH=amd64
else ifeq ($(UNAME_M), aarch64)
	ARCH=arm64
else 
	ARCH=$(UNAME_M)
endif

BUILD_META=-build$(shell date +%Y%m%d)
ORG ?= rancher
# the metrics server has been moved to https://github.com/kubernetes-sigs/metrics-server
# but still refers internally to github.com/kubernetes-incubator/metrics-server packages
PKG ?= github.com/kubernetes-incubator/metrics-server
SRC ?= github.com/kubernetes-sigs/metrics-server
TAG ?= ${GITHUB_ACTION_TAG}

ifeq ($(TAG),)
TAG := v0.7.2$(BUILD_META)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG $(TAG) needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker buildx build \
		--platform=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--build-arg ARCH=$(ARCH) \
		--target k8s-metrics-server \
		--tag $(ORG)/hardened-k8s-metrics-server:$(TAG) \
		--tag $(ORG)/hardened-k8s-metrics-server:$(TAG)-$(ARCH) \
		--load \
	.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-k8s-metrics-server:$(TAG)-$(ARCH)

.PHONY: image-scan
image-scan:
	trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-k8s-metrics-server:$(TAG)


PHONY: log
log:
	@echo "ARCH=$(ARCH)"
	@echo "TAG=$(TAG:$(BUILD_META)=)"
	@echo "ORG=$(ORG)"
	@echo "PKG=$(PKG)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"
