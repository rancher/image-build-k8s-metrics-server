ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/build-base:v1.14.2

FROM ${UBI_IMAGE} as ubi

FROM ${GO_IMAGE} as builder
ARG TAG="" 
RUN apt update     && \ 
    apt upgrade -y && \ 
    apt install -y ca-certificates git

RUN git clone --depth=1 https://github.com/kubernetes-sigs/metrics-server.git $GOPATH/src/github.com/kubernetes-sigs/metrics-server
RUN mkdir -p $GOPATH/src/github.com                                                           && \
    cd $GOPATH/src/github.com/kubernetes-sigs/metrics-server                                  && \
    git fetch --all --tags --prune                                                            && \
    git checkout tags/${TAG} -b ${TAG}                                                        && \
    cp -ar $GOPATH/src/github.com/kubernetes-sigs $GOPATH/src/github.com/kubernetes-incubator && \
    CGO_ENABLED=1 make all

FROM ubi
ARG ARCH=amd64

COPY --from=builder /go/src/github.com/kubernetes-sigs/metrics-server/_output/${ARCH}/metrics-server /

