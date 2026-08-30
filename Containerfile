FROM quay.io/fedora/fedora-silverblue:44

COPY --from=ghcr.io/ublue-os/brew:latest /system_files /

COPY /rootfs /

RUN --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/lib/rpm-state \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=bind,dst=/tmp/build.sh,source=build.sh \
    bash /tmp/build.sh

RUN bootc container lint
