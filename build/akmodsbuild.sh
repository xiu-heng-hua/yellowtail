#!/usr/bin/env bash
set -euxo pipefail

KERNEL_RELEASE=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-devel-matched)

dnf download \
    --from-repo=rpmfusion-nonfree-updates-source \
    --srpm \
    nvidia-kmod

dnf builddep nvidia-kmod-*.src.rpm

dnf install akmodsbuild

useradd -m akmodsbuild

sudo -u akmodsbuild akmodsbuild \
    -k ${KERNEL_RELEASE} \
    -o /var/home/akmodsbuild \
    nvidia-kmod-*.src.rpm
