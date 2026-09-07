# RakuOS Hyprland Image
ARG BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-staging}"
ARG BASE_IMAGE_REPO="quay.io/rakuos/rakuos-base-nvidia-v3"
ARG RAKUOS_STAGING="0"

FROM ${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG}
ENV BASE_IMAGE_TAG=${BASE_IMAGE_TAG}
ENV RAKUOS_STAGING=${RAKUOS_STAGING}

COPY build_files /
COPY system_files /

RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /build.sh && /post-build.sh && /post-build-overlay.sh
