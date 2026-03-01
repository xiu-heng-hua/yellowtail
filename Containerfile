ARG FEDORA_VERSION=43

FROM quay.io/fedora/fedora-silverblue:${FEDORA_VERSION} as common

ARG FEDORA_VERSION

RUN --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/log <<EORUN
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
EORUN

FROM common as kmod-nvidia

RUN --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/log <<EORUN
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
EORUN

FROM common

RUN --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/log <<EORUN
#!/usr/bin/env bash
set -euxo pipefail

dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo

rpm --import \
    https://packages.microsoft.com/keys/microsoft.asc

echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo

curl -o /etc/flatpak/remotes.d/flathub.flatpakrepo \
    https://dl.flathub.org/repo/flathub.flatpakrepo

dnf install code just steam tailscale

sudo systemctl enable tailscaled
EORUN

COPY --from=kmod-nvidia /var/home/akmodsbuild /tmp/akmodsbuild

RUN --mount=type=tmpfs,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/lib/dnf \
    --mount=type=tmpfs,dst=/var/log <<EORUN
#!/usr/bin/env bash
set -euxo pipefail

dnf --setopt=localpkg_gpgcheck=0 install /tmp/akmodsbuild/*.rpm

cat > /usr/lib/bootc/kargs.d/kmod-nvidia-blacklist.toml <<EOF
kargs = [
    "rd.driver.blacklist=nouveau,nova_core",
    "modprobe.blacklist=nouveau,nova_core",
]
EOF
EORUN
