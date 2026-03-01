ARG FEDORA_VERSION=43

FROM quay.io/fedora/fedora-silverblue:${FEDORA_VERSION} as common

ARG FEDORA_VERSION

RUN --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=bind,dst=/tmp/build.sh,source=build/common.sh \
    bash /tmp/build.sh

FROM common as akmodsbuild

RUN --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=bind,dst=/tmp/build.sh,source=build/akmodsbuild.sh \
    bash /tmp/build.sh

FROM common

RUN --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=bind,dst=/tmp/build.sh,source=build/yellowtail-base.sh \
    bash /tmp/build.sh

COPY --from=akmodsbuild /var/home/akmodsbuild /tmp/akmodsbuild

RUN --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=bind,dst=/tmp/build.sh,source=build/yellowtail-kmods.sh \
    bash /tmp/build.sh

RUN bootc container lint
