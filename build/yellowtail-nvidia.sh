#!/usr/bin/env bash
set -euxo pipefail

dnf --setopt=localpkg_gpgcheck=0 install /tmp/akmodsbuild/*.rpm

cat > /usr/lib/bootc/kargs.d/kmod-nvidia-blacklist.toml <<EOF
kargs = [
    "rd.driver.blacklist=nouveau,nova_core",
    "modprobe.blacklist=nouveau,nova_core",
]
EOF
