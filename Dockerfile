ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.15.2b5
FROM ${UBI_IMAGE} as ubi
FROM ${GO_IMAGE} as builder
# setup required packages
RUN set -x \
 && apk --no-cache add \
    file \
    gcc \
    git \
    libselinux-dev \
    libseccomp-dev \
    make
# setup the build
ARG PKG="github.com/kubernetes-incubator/metrics-server"
ARG SRC="github.com/kubernetes-sigs/metrics-server"
ARG TAG="v0.3.6"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN go run vendor/k8s.io/kube-openapi/cmd/openapi-gen/openapi-gen.go --logtostderr \
    -i k8s.io/metrics/pkg/apis/metrics/v1beta1,k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/apimachinery/pkg/api/resource,k8s.io/apimachinery/pkg/version \
    -p ${PKG}/pkg/generated/openapi/ \
    -O zz_generated.openapi \
    -h $(pwd)/hack/boilerplate.go.txt \
    -r /dev/null
RUN GO_LDFLAGS="-linkmode=external \
    -X ${PKG}/pkg/version.Version=${TAG} \
    -X ${PKG}/pkg/version.gitCommit=$(git rev-parse HEAD) \
    -X ${PKG}/pkg/version.gitTreeState=clean \
    " \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/metrics-server ./cmd/metrics-server
RUN go-assert-static.sh bin/*
RUN go-assert-boring.sh bin/*
RUN install -s bin/* /usr/local/bin
RUN metrics-server --help

FROM ubi
RUN microdnf update -y && \
    rm -rf /var/cache/yum
COPY --from=builder /usr/local/bin/metrics-server /
ENTRYPOINT ["/metrics-server"]
