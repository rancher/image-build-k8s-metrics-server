#ARG BCI_IMAGE=registry.suse.com/bci/bci-micro
ARG GO_IMAGE=rancher/hardened-build-base:v1.23.1b1

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.3.0 as xx

#FROM ${BCI_IMAGE} as bci
FROM --platform=$BUILDPLATFORM ${GO_IMAGE} as base-builder
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
FROM base-builder as metrics-builder
ARG PKG="github.com/kubernetes-incubator/metrics-server"
ARG SRC="github.com/kubernetes-sigs/metrics-server"
ARG TAG=v0.7.2
ARG TARGETARCH
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN go mod download
RUN go install -mod=readonly -modfile=scripts/go.mod k8s.io/kube-openapi/cmd/openapi-gen && \
    ${GOPATH}/bin/openapi-gen --logtostderr \
    -i k8s.io/metrics/pkg/apis/metrics/v1beta1,k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/apimachinery/pkg/api/resource,k8s.io/apimachinery/pkg/version \
    -p ${PKG}/pkg/generated/openapi/ \
    -O zz_generated.openapi \
    -h $(pwd)/scripts/boilerplate.go.txt \
    -r /dev/null;
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

FROM ${GO_IMAGE} as strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=metrics-builder /usr/local/bin/metrics-server /usr/local/bin
RUN metrics-server --help
RUN strip /usr/local/bin/metrics-server

FROM scratch as k8s-metrics-server
COPY --from=strip_binary /usr/local/bin/metrics-server /
ENTRYPOINT ["/metrics-server"]
