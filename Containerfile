ARG FEDORA_VERSION=44

FROM quay.io/fedora/fedora-silverblue:${FEDORA_VERSION}

ARG FEDORA_VERSION

RUN --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=bind,dst=/tmp/build.sh,source=build/base.sh \
    bash /tmp/build.sh

RUN bootc container lint
