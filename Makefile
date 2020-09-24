SEVERITIES = HIGH,CRITICAL

ifeq ($(ARCH),)
ARCH=$(shell go env GOARCH)
endif

ORG ?= rancher
# the metrics server has been moved to https://github.com/kubernetes-sigs/metrics-server
# but still refers internally to github.com/kubernetes-incubator/metrics-server packages
PKG ?= github.com/kubernetes-incubator/metrics-server
SRC ?= github.com/kubernetes-sigs/metrics-server
TAG ?= v0.3.6

ifneq ($(DRONE_TAG),)
TAG := $(DRONE_TAG)
endif

.PHONY: image-build
image-build:
	docker build \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG) \
		--tag $(ORG)/hardened-k8s-metrics-server:$(TAG) \
		--tag $(ORG)/hardened-k8s-metrics-server:$(TAG)-$(ARCH) \
	.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-k8s-metrics-server:$(TAG)-$(ARCH)

.PHONY: image-manifest
image-manifest:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-k8s-metrics-server:$(TAG) \
		$(ORG)/hardened-k8s-metrics-server:$(TAG)-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-k8s-metrics-server:$(TAG)

.PHONY: image-scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-k8s-metrics-server:$(TAG)
