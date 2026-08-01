# yellowtail

[![Build and Push the Container Images](https://github.com/xiu-heng-hua/yellowtail/actions/workflows/build.yml/badge.svg)](https://github.com/xiu-heng-hua/yellowtail/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A [Fedora Silverblue](https://fedoraproject.org/atomic-desktops/silverblue/)
image with a custom toolset already baked in.

Silverblue is an image-based desktop: the operating system is one immutable
image that you boot into, and updating means downloading a new image rather than
upgrading individual packages. yellowtail is that image, rebuilt every night, so
the software below is part of the OS instead of something you layer on top of it
after every install.

## Variants

| Image | Pull from | Use it when |
| --- | --- | --- |
| `yellowtail` | `ghcr.io/xiu-heng-hua/yellowtail` | You use Intel or AMD graphics. |
| `yellowtail-nvidia` | `ghcr.io/xiu-heng-hua/yellowtail-nvidia` | You have an NVIDIA card and want the proprietary driver. |

Every build publishes two tags:

| Tag | Example | What it is for |
| --- | --- | --- |
| `latest` | `latest` | What you normally want — follows the nightly build. |
| Build date | `2026-08-01` | Pin to, or roll back to, a specific day. |

## What is inside

On top of stock Silverblue:

- **Repositories** — RPM Fusion (free and nonfree), [Terra](https://terra.fyralabs.com/),
  Flathub, and the vendor repositories for the packages below.
- **Desktop** — [Ghostty](https://ghostty.org/), GNOME Tweaks, `ibus-mozc` for
  Japanese input.
- **Development** — [Claude Code](https://claude.com/claude-code), Visual Studio
  Code, the GitHub CLI, [`just`](https://just.systems/), `rustup`.
- **Virtualisation and remote access** — Cockpit with the machines plugin,
  Tailscale (`tailscaled` is enabled and starts on first boot).
- **Gaming and media** — Steam, and full `ffmpeg` swapped in for `ffmpeg-free`
  so hardware and patent-encumbered codecs work.

The NVIDIA variant additionally builds `nvidia-kmod` against the image's exact
kernel and blacklists `nouveau` and `nova_core`.

## Installing

> [!WARNING]
> Rebasing replaces your operating system. Your `/home` and your Flatpaks are
> untouched, but packages you layered with `rpm-ostree install` are not carried
> over. You can always roll back — see [Rolling back](#rolling-back).

From an existing Fedora Silverblue installation:

```sh
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/xiu-heng-hua/yellowtail:latest
sudo systemctl reboot
```

For the NVIDIA variant, use `ghcr.io/xiu-heng-hua/yellowtail-nvidia:latest`
instead.

On a system that already ships `bootc`, this is equivalent:

```sh
sudo bootc switch --transport registry ghcr.io/xiu-heng-hua/yellowtail:latest
sudo systemctl reboot
```

If you are not on an atomic Fedora desktop yet, install
[Fedora Silverblue](https://fedoraproject.org/atomic-desktops/silverblue/) first
and then rebase.

## Updating

Updates are automatic once you are rebased — the same mechanism Silverblue
already uses. To pull one immediately:

```sh
sudo rpm-ostree upgrade
sudo systemctl reboot
```

The images are rebuilt every night at 00:00 UTC, so a new build lands roughly
daily. Downloads are small: the image is
[rechunked](https://github.com/hhd-dev/rechunk) before publishing, which splits
it into stable, package-aligned layers so a nightly update transfers only the
layers that actually changed instead of the whole image.

## Rolling back

To boot the previous deployment once, pick it from the GRUB menu at startup. To
go back permanently:

```sh
sudo rpm-ostree rollback
sudo systemctl reboot
```

To return to stock Silverblue:

```sh
sudo rpm-ostree rebase fedora:fedora/44/x86_64/silverblue
sudo systemctl reboot
```

To pin a specific day rather than tracking `latest`, rebase onto a dated tag:

```sh
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/xiu-heng-hua/yellowtail:2026-08-01
```

## Verifying the images

Published images are signed with [cosign](https://github.com/sigstore/cosign).
Verify a pull against the `cosign.pub` in this repository:

```sh
cosign verify --key cosign.pub ghcr.io/xiu-heng-hua/yellowtail:latest
```

Rebasing still uses the `ostree-unverified-registry:` transport shown above.
rpm-ostree only checks a signature when the image itself carries a matching
policy, which means shipping `cosign.pub` at `/etc/pki/containers/` with an
entry in `/etc/containers/policy.json` — until then the transport has to be told
not to expect one.

If you fork this, generate your own pair. The private key and its password go
straight into the fork's Actions secrets and never touch your disk, leaving only
`cosign.pub` to commit:

```sh
podman run --rm --user 0:0 \
  -e GITHUB_TOKEN="$(gh auth token)" \
  -e COSIGN_PASSWORD="$(head -c 32 /dev/urandom | base64)" \
  -v .:/work:z -w /work \
  gcr.io/projectsigstore/cosign:v2.4.3 \
  generate-key-pair github://<owner>/<repo>
```

`--user 0:0` maps container root back to your own uid under rootless podman, so
`cosign.pub` comes out owned by you rather than unwritable. `COSIGN_PASSWORD` is
required even though you never need to know it: cosign encrypts the key before
uploading, and prompts for a password it cannot read without a terminal. Signing
switches itself on as soon as `COSIGN_PRIVATE_KEY` exists; without it the
signing steps are skipped and the build is unchanged.

## Building locally

You need `podman` (or `buildah`) and enough disk for a full Silverblue image.
Build with root so the result can be inspected and mounted the same way CI does:

```sh
sudo podman build --file Containerfile --tag yellowtail .
```

The NVIDIA variant builds on top of the image you just made, so build the base
first:

```sh
sudo podman build --file Containerfile.nvidia --tag yellowtail-nvidia .
```

To build against a different Fedora release, override the build argument:

```sh
sudo podman build --build-arg FEDORA_VERSION=45 --file Containerfile --tag yellowtail .
```

Each Containerfile ends with `bootc container lint`, so a build that succeeds is
also a valid bootable container.

## Layout

```
Containerfile           the main image
Containerfile.nvidia    the NVIDIA variant, built from the main image
build/base.sh           repositories, packages and services for the main image
build/nvidia-kmod.sh    builds nvidia-kmod against the image's kernel
build/nvidia.sh         installs the built driver and blacklists nouveau
.github/workflows/build.yml
                        nightly build, rechunk, push and sign
```

Changing what the image contains almost always means editing `build/base.sh`.

## License

[MIT](LICENSE)
