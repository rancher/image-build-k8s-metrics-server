#ARG BCI_IMAGE=registry.suse.com/bci/bci-micro
ARG GO_IMAGE=rancher/hardened-build-base:v1.26.4b1

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.6.1 AS xx

#FROM ${BCI_IMAGE} AS bci
FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base-builder
# copy xx scripts to your build stage
COPY --from=xx / /
RUN apk add file make git clang lld 
ARG TARGETPLATFORM
# setup required packages
RUN set -x && \
    xx-apk --no-cache add \
    gcc \
    musl-dev \
    build-base \
    libselinux-dev \
    libseccomp-dev 

# setup the build
FROM base-builder AS metrics-builder
ARG PKG="github.com/kubernetes-incubator/metrics-server"
ARG SRC="github.com/kubernetes-sigs/metrics-server"
ARG TAG=v0.8.1
ARG COMMIT="c9e288072361b9b155b1137b7109601c64b05984"
ARG TARGETARCH
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git fetch --depth 1 origin ${COMMIT} && git checkout ${COMMIT}
RUN go mod edit -replace github.com/go-openapi/swag=github.com/go-openapi/swag@v0.23.0 && \
    go mod edit -replace github.com/go-openapi/testify/v2=github.com/go-openapi/testify/v2@v2.1.0 && \
    go mod edit -replace github.com/prometheus/prometheus=github.com/prometheus/prometheus@v0.311.3 && \
    go mod edit -replace google.golang.org/grpc=google.golang.org/grpc@v1.79.3 && \
    go mod edit -replace go.opentelemetry.io/otel/sdk=go.opentelemetry.io/otel/sdk@v1.43.0 && \
    go mod tidy && go mod vendor
RUN go mod download
RUN go get -tool k8s.io/kube-openapi/cmd/openapi-gen@v0.0.0-20260127142750-a19766b6e2d4 && \
    go tool k8s.io/kube-openapi/cmd/openapi-gen \
    --output-pkg ${PKG}/pkg/generated/openapi/ \
    --output-file=zz_generated.openapi.go \
    --output-dir=${PKG}/pkg/api/generated/openapi \
    --go-header-file $(pwd)/scripts/boilerplate.go.txt \
    --report-filename /dev/null \
    k8s.io/metrics/pkg/apis/metrics/v1beta1 k8s.io/apimachinery/pkg/apis/meta/v1 k8s.io/apimachinery/pkg/api/resource k8s.io/apimachinery/pkg/version

# cross-compilation setup
ARG TARGETPLATFORM
RUN xx-go --wrap && \
    CGO_ENABLED=1 \
    GO_LDFLAGS="-linkmode=external \
    -X ${PKG}/pkg/version.Version=${TAG} \
    -X ${PKG}/pkg/version.gitCommit=$(git rev-parse HEAD) \
    -X ${PKG}/pkg/version.gitTreeState=clean \
    " \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/metrics-server ./cmd/metrics-server
RUN go-assert-static.sh bin/*
RUN xx-verify --static bin/*
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
       go-assert-boring.sh bin/*; \
    fi
RUN install bin/metrics-server /usr/local/bin

FROM ${GO_IMAGE} AS strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=metrics-builder /usr/local/bin/metrics-server /usr/local/bin
RUN metrics-server --help
RUN strip /usr/local/bin/metrics-server

FROM scratch AS k8s-metrics-server
COPY --from=strip_binary /usr/local/bin/metrics-server /
ENTRYPOINT ["/metrics-server"]
