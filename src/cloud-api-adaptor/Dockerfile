ARG BUILD_TYPE=dev
# golang:1.25.9
ARG BUILDER_BASE=golang@sha256:a95d3d115ec2643a014c9539962dcecba297fb4ed5e5cbfab84cf726327e8b8c
# debian:bookworm-slim (matches golang:1.25.9 base for glibc compatibility)
# Multi-arch manifest list digest supporting amd64, arm64, s390x, ppc64le, etc.
ARG BASE=debian@sha256:4724b8cc51e33e398f0e2e15e18d5ec2851ff0c2280647e1310bc1642182655d

# This dockerfile uses Go cross-compilation to build the binary,
# we build on the host platform ($BUILDPLATFORM) and then copy the
# binary into the container image of the target platform ($TARGETPLATFORM)
# that was specified with --platform. For more details see:
# https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/
FROM --platform=$BUILDPLATFORM $BUILDER_BASE AS builder-release
ARG YQ_VERSION
RUN go install github.com/mikefarah/yq/v4@$YQ_VERSION

# For `dev` builds due to CGO constraints we have to emulate the target platform
# instead of using Go's cross-compilation
FROM $BUILDER_BASE AS builder-dev
ARG YQ_VERSION
RUN apt-get update && \
    apt-get install -y libvirt-dev pkg-config binutils-gold && \
    rm -rf /var/lib/apt/lists/*
RUN go install github.com/mikefarah/yq/v4@$YQ_VERSION

FROM builder-${BUILD_TYPE} AS builder
ARG RELEASE_BUILD
ARG COMMIT
ARG VERSION
ARG TARGETARCH

WORKDIR /work
COPY cloud-api-adaptor/go.mod cloud-api-adaptor/go.sum ./cloud-api-adaptor/
COPY cloud-providers ./cloud-providers
COPY peerpod-ctrl ./peerpod-ctrl
WORKDIR /work/cloud-api-adaptor
RUN go mod download
COPY cloud-api-adaptor/entrypoint.sh cloud-api-adaptor/Makefile cloud-api-adaptor/Makefile.defaults cloud-api-adaptor/versions.yaml ./
COPY cloud-api-adaptor/cmd   ./cmd
COPY cloud-api-adaptor/pkg   ./pkg
COPY cloud-api-adaptor/proto ./proto

RUN CC=gcc ARCH=$TARGETARCH make COMMIT=$COMMIT VERSION=$VERSION RELEASE_BUILD=$RELEASE_BUILD cloud-api-adaptor

FROM builder-release AS iptables

ARG TARGETARCH

WORKDIR /iptables
RUN --mount=type=bind,target=/versions.yaml,source=cloud-api-adaptor/versions.yaml,readonly \
    version=$(yq -r .tools.iptables-wrapper /versions.yaml) && \
    GOARCH=$TARGETARCH go install "github.com/kubernetes-sigs/iptables-wrappers@$version" && \
    find /go/bin -name iptables-wrappers -exec cp {} ./iptables-wrapper \; && \
    curl -L -o iptables-wrapper-installer.sh "https://raw.githubusercontent.com/kubernetes-sigs/iptables-wrappers/${version#v*-*-}/iptables-wrapper-installer.sh" && \
    chmod 755 iptables-wrapper-installer.sh

FROM $BASE AS base-release

RUN apt-get update && \
    apt-get install -y iptables && \
    rm -rf /var/lib/apt/lists/*
RUN --mount=type=cache,target=/iptables,from=iptables,source=/iptables,readonly \
    cd /iptables && ./iptables-wrapper-installer.sh --no-sanity-check --no-cleanup

FROM base-release AS base-dev
RUN apt-get update && \
    apt-get install -y libvirt0 openssh-client && \
    rm -rf /var/lib/apt/lists/*

FROM base-${BUILD_TYPE}
COPY --from=builder /work/cloud-api-adaptor/cloud-api-adaptor /work/cloud-api-adaptor/entrypoint.sh /usr/local/bin/
CMD ["entrypoint.sh"]
