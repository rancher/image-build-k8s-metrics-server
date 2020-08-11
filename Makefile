
SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t rancher/k8s-metrics-server:$(TAG) .

.PHONY: image-push
image-push:
	docker push rancher/k8s-metrics-server:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed rancher/k8s-metrics-server:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect rancher/k8s-metrics-server:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create rancher/k8s-metrics-server:$(TAG) \
		$(shell docker image inspect rancher/k8s-metrics-server:$(TAG) | jq -r '.[] | .RepoDigests[0]')
