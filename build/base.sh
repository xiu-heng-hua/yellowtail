#!/usr/bin/env bash
set -euxo pipefail

dnf config-manager setopt \
    assumeyes=1 \
    fastestmirror=1 \
    localpkg_gpgcheck=1 \
    max_parallel_downloads=16

# Repositories

# distribution-gpg-keys ships the RPM Fusion keys in the base image, so the
# release packages below can be verified without fetching a key over the wire.
rpm --import \
    /usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-${FEDORA_VERSION} \
    /usr/share/distribution-gpg-keys/rpmfusion/RPM-GPG-KEY-rpmfusion-nonfree-fedora-${FEDORA_VERSION}

dnf install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm

# Terra carries its key inside terra-release itself, so that one package cannot
# be checked before it is installed. Everything from Terra after it can be.
dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release

# Claude Code
cat > /etc/yum.repos.d/claude-code.repo <<'EOF'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF

# Visual Studio Code
rpm --import \
    https://packages.microsoft.com/keys/microsoft.asc

cat > /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Flathub
curl -o /etc/flatpak/remotes.d/flathub.flatpakrepo \
    https://dl.flathub.org/repo/flathub.flatpakrepo

# Packages

# The nvidia variant builds akmods against this image's kernel, so the headers
# are held at that version for the rest of the build.
dnf install kernel-devel-matched
dnf versionlock add kernel-devel-matched

# Hardware and patent-encumbered codecs.
dnf swap --allowerasing ffmpeg-free ffmpeg

packages=(
    # Desktop
    ghostty
    ibus-mozc
    jetbrains-mono-fonts
    # Development
    claude-code
    code
    gh
    just
    nodejs24
    rustup
    uv
    # Gaming
    steam
)

dnf install "${packages[@]}"

# Desktop defaults

# The login screen takes its keyboard from systemd-localed, not from any user's
# settings, so it needs this file as well as the schema default below. localectl
# would normally write it, but that needs a running localed, which a container
# build does not have. Nothing in the base image creates xorg.conf.d, because
# nothing has configured a keyboard yet.
mkdir -p /etc/X11/xorg.conf.d

cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<'EOF'
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "custom"
        Option "XkbOptions" "ctrl:swapcaps"
EndSection
EOF

# The custom layout, and Caps Lock swapped with Ctrl. These are schema defaults
# rather than any user's dconf, so they apply to a fresh account and can still
# be changed with gsettings. glib reads .override files in filename order and
# the last one wins, so zz- puts this after the overrides Fedora ships.
cat > /usr/share/glib-2.0/schemas/zz-yellowtail.gschema.override <<'EOF'
[org.gnome.desktop.input-sources]
sources=[('xkb','custom'),('ibus','mozc-jp')]
xkb-options=['ctrl:swapcaps']
EOF

glib-compile-schemas /usr/share/glib-2.0/schemas
