# Global build arg — available to all FROM lines for image tag resolution.
# Must NOT have ENV here; ENV is a layer instruction and cannot precede FROM.
ARG BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-staging}"
ARG BASE_IMAGE_REPO="quay.io/rakuos/rakuos-base-nvidia-v3"
ARG CHUNKAH_CONFIG_STR

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Pull the RakuOS base image from Quay.
# BASE_IMAGE_TAG is re-declared inside this stage (ARG values defined before
# the first FROM must be re-declared in each stage that needs them).
FROM ${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG} AS builder
ARG BASE_IMAGE_TAG
ENV BASE_IMAGE_TAG=${BASE_IMAGE_TAG}
# Set by CI to "1" on the staging branch so build.sh installs the
# rakuos-release-<de>-staging variant instead of rakuos-release-<de>.
ARG RAKUOS_STAGING="1"
ENV RAKUOS_STAGING=${RAKUOS_STAGING}
COPY system_files /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && /ctx/post-build.sh && /ctx/post-build-overlay.sh

COPY system_files /

RUN bootc container lint

FROM quay.io/coreos/chunkah AS chunkah
ARG CHUNKAH_CONFIG_STR
RUN --mount=from=builder,src=/,target=/chunkah,ro \
    --mount=type=bind,target=/run/src,rw \
        chunkah build --prune /sysroot/ --max-layers 128 --compressed --threads 16 \
          --label ostree.commit- --label ostree.final-diffid- \
          > /run/src/out.ociarchive

FROM oci-archive:out.ociarchive
LABEL containers.bootc=1
