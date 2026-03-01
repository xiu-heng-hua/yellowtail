#!/usr/bin/env bash
set -euxo pipefail

dnf config-manager setopt \
    assumeyes=1 \
    fastestmirror=1 \
    localpkg_gpgcheck=1 \
    max_parallel_downloads=16

rpm --import \
    /usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-${FEDORA_VERSION} \
    /usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-nonfree-fedora-${FEDORA_VERSION}

dnf install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm

dnf install kernel-devel-matched

dnf versionlock add kernel-devel-matched
