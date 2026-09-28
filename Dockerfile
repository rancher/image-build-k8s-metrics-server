ARG GO_IMAGE=rancher/hardened-build-base:v1.26.8b1

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.6.1 AS xx

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
ARG PKG="github.com/kubernetes-sigs/metrics-server"
ARG TAG
ARG TARGETARCH
RUN git clone --depth=1 https://${PKG}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
COPY go-mod-overrides ./go-mod-overrides
RUN go-mod-overrides.sh ./go-mod-overrides
RUN go mod download

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
