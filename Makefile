
SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t rancher/hardened-k8s-metrics-server:$(TAG) .

.PHONY: image-push
image-push:
	docker push rancher/hardened-k8s-metrics-server:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed rancher/hardened-k8s-metrics-server:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect rancher/hardened-k8s-metrics-server:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create rancher/hardened-k8s-metrics-server:$(TAG) \
		$(shell docker image inspect rancher/hardened-k8s-metrics-server:$(TAG) | jq -r '.[] | .RepoDigests[0]')
