# Global build arg — available to all FROM lines for image tag resolution.
# Must NOT have ENV here; ENV is a layer instruction and cannot precede FROM.
ARG BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-staging}"
ARG BASE_IMAGE_REPO="quay.io/rakuos/rakuos-base-nvidia-v3"

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Pull the RakuOS base image from Quay.
FROM ${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG} AS builder
ARG BASE_IMAGE_TAG
ENV BASE_IMAGE_TAG=${BASE_IMAGE_TAG}
ARG RAKUOS_STAGING="1"
ENV RAKUOS_STAGING=${RAKUOS_STAGING}
COPY system_files /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && /ctx/post-build.sh && /ctx/post-build-overlay.sh

COPY system_files /

RUN rm -rf /run/* /tmp/* 2>/dev/null || true; \
    sed -i '/^wbpriv:/d' /etc/group 2>/dev/null || true; \
    sed -i '/^.*:x:964:/d' /etc/group 2>/dev/null || true; \
    grep -q '^root:' /etc/group || echo 'root:x:0:' >> /etc/group; \
    bootc container lint

LABEL containers.bootc=1
