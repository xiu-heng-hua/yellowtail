#!/usr/bin/env bash
set -euxo pipefail

test -f /etc/pki/containers/yellowtail.pub

fedora=$(rpm -E %fedora)

dnf config-manager setopt assumeyes=1 localpkg_gpgcheck=1

rpm --import \
    "/usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-${fedora}" \
    "/usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-nonfree-fedora-${fedora}"

dnf install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora}.noarch.rpm"

dnf install --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" terra-release

dnf config-manager setopt terra.metalink="" terra.baseurl="https://repos.fyralabs.com/terra\$releasever/"

dnf swap --allowerasing ffmpeg-free ffmpeg

dnf install \
    claude-code \
    fuse \
    fuse-libs \
    gcc \
    ibus-mozc \
    make \
    patch \
    steam \
    virt-manager \
    xdg-terminal-exec

dnf swap ptyxis ghostty

dnf remove terra-release

dnf install console-setup

ckbcomp -I/etc/xkb fr-qwerty "" ctrl:swapcaps |
    gzip > /usr/lib/kbd/keymaps/xkb/fr-qwerty.map.gz

dnf remove console-setup

glib-compile-schemas /usr/share/glib-2.0/schemas

semodule --noreload --install /usr/share/selinux/packages/yellowtail_virt_hooks.cil
semanage boolean --noreload --modify --on virt_hooks_unconfined
rm -rf /etc/selinux/targeted/previous

systemctl enable brew-setup.service brew-update.timer brew-upgrade.timer

python3 -c "
import sqlite3
db = sqlite3.connect('/usr/share/rpm/rpmdb.sqlite')
db.execute('pragma journal_mode = delete')
db.close()
"
