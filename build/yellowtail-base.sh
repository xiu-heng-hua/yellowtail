#!/usr/bin/env bash
set -euxo pipefail

rpm --import \
    https://packages.microsoft.com/keys/microsoft.asc

echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo

dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo

curl -o /etc/flatpak/remotes.d/flathub.flatpakrepo \
    https://dl.flathub.org/repo/flathub.flatpakrepo

dnf install code just steam tailscale

sudo systemctl enable tailscaled
