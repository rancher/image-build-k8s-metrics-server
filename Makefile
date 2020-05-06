SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t ranchertest/k8s-metrics-server:$(TAG) .

.PHONY: image-push
image-push:
	docker push ranchertest/k8s-metrics-server:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed ranchertest/k8s-metrics-server:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect ranchertest/k8s-metrics-server:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create fips-image-build-flannel:$(TAG) \
		$(shell docker image inspect ranchertest/k8s-metrics-server:$(TAG) | jq -r \'.[] | .RepoDigests[0]\')
