# Yellowtail

A [Fedora Silverblue](https://fedoraproject.org/atomic-desktops/silverblue/)
image for x86-64 desktops, built as a [bootc](https://bootc.dev/) bootable
container.

Silverblue is image-based: the operating system is one immutable image you boot
into, and updating means downloading a new image rather than upgrading packages.
Yellowtail is that image, rebuilt every night.

## What is inside

The image holds only what has to live on the host. Everything else comes from a
layer that updates without rebuilding or rebooting.

| Layer | Holds | Managed by |
| --- | --- | --- |
| Image | desktop, codecs, terminal | this repository |
| [Flatpak](https://flatpak.org/) | GUI applications | [`yellowtail.preinstall`][preinstall] |
| [Homebrew](https://brew.sh/) | command-line tools | you, per machine |

On top of stock Silverblue the image adds [Ghostty](https://ghostty.org/) as the
only terminal, [Claude Code](https://claude.com/claude-code),
[Steam](https://store.steampowered.com/), [Mozc](https://github.com/google/mozc)
for Japanese input, [virt-manager](https://virt-manager.org/) for virtual
machines, and full `ffmpeg` in place of `ffmpeg-free`. The package list is in
[`build.sh`][build]. [Firefox](https://www.mozilla.org/firefox/) comes from the
base image, with Fedora's start page, pinned tile and default bookmarks removed.

The image also carries what a virtual machine needs to borrow a graphics card:
a [libvirt hook][hook] that takes any PCI device a machine passes through
unmanaged away from whatever holds it, the desktop included, when the machine
starts, and gives it back when the machine stops, and an [SELinux module][cil]
without which libvirt could not run that hook at all, a [`windows`
command][windows-cmd] that starts, stops and reports on the machine, and a
small disc it can hand to Windows with the [keyboard layout][klc] and the
other settings Windows cannot inherit from Linux. The machine itself is created
per computer; see [Windows](#windows).

It also carries a French QWERTY keyboard layout: QWERTY letters, with the
accented characters on AltGr. [GNOME](https://www.gnome.org/) lists it as
*French (QWERTY)* and its indicator reads `fr`. A fresh account starts with that
layout and Mozc as its two input sources, Caps Lock swapped with Ctrl, and
GNOME's Blobs wallpaper. The virtual consoles use the same layout. All of that
is a default in [`zz-yellowtail.gschema.override`][gschema], so changing any of
it in Settings works and sticks.

[Flathub](https://flathub.org/) is preconfigured, and
[`rootfs/usr/share/flatpak/preinstall.d/yellowtail.preinstall`][preinstall]
names the applications to install: [Bitwarden](https://bitwarden.com/),
[Discord](https://discord.com/), [Thunderbird](https://www.thunderbird.net/),
[VSCodium](https://vscodium.com/) and [Gear
Lever](https://mijorus.it/projects/gearlever/), which integrates AppImages into
the desktop, alongside the six GNOME applications the desktop itself reaches for
— Sushi for the spacebar preview in Files, Extensions, Characters, Fonts, Image
Viewer and Document Viewer. Nothing installs them on its own; run this once on a
new machine:

```sh
sudo flatpak preinstall
```

Command-line tools are not in the image, but Homebrew is. It unpacks itself on
first boot, so `brew install` works with nothing to set up. It lives in
`/home/linuxbrew`, which is machine-local, so it never touches `/usr` and
survives image updates.

## Installing

These instructions assume you are already running Fedora Silverblue, or another
[rpm-ostree](https://coreos.github.io/rpm-ostree/) or bootc based system.

> [!WARNING]
> Rebasing replaces your operating system. Your `/home` and your Flatpaks are
> untouched, but packages layered with `rpm-ostree install` are not carried
> over.

```sh
sudo bootc switch --transport registry ghcr.io/xiu-heng-hua/yellowtail:latest
sudo systemctl reboot
```

## Updating

Updates are automatic: GNOME Software stages a new image in the background, and
you boot into it the next time you restart. To pull one immediately:

```sh
sudo bootc upgrade
sudo systemctl reboot
```

Builds run nightly at 00:00 UTC. An update transfers the one layer holding
everything this repository adds, and the base image's own layers whenever Fedora
republishes them.

## Rolling back

To boot the previous deployment once, pick it from the GRUB menu. To go back
permanently:

```sh
sudo bootc rollback
sudo systemctl reboot
```

To pin a specific day rather than tracking `latest`, switch to a dated tag,
named for the UTC day its build ran:

```sh
sudo bootc switch --transport registry ghcr.io/xiu-heng-hua/yellowtail:YYYY-MM-DD
```

Only days a build ran carry a tag; the [package listing][packages] shows which
ones exist.

## Windows

Some software only exists for Windows, and some of it needs a real graphics
card behind a real Windows driver. So Windows runs in a virtual machine that is
given a graphics card for as long as it runs. Where that card is the only one,
the desktop has to go while Windows has it. Linux keeps running underneath, and
where the computer has a second GPU, a processor's built-in one for instance,
the desktop comes straight back on that.

The machine belongs to the system libvirt: only that one runs [the hook][hook]
that does the hand-over, and only it may pass hardware through. virt-manager
opens it by default, but `virsh` run by a user opens a private one unless told
otherwise, so the `virsh` command below names it with `-c qemu:///system`, and
so does the [`windows` command][windows-cmd] that drives the machine once it
exists. Your account has to be in the `libvirt` group, as [described
below](#virtual-machines-arrive-without-their-state-directories).

1. Create the machine in virt-manager from a Windows 11 installer, and name it
   `windows`, which is the name the command expects. virt-manager
   sets UEFI and adds a TPM when it recognises the installer, and Windows 11
   refuses to install without them, so a slip there shows itself before
   anything else. Install Windows through the emulated display. That proves
   the disk, the network and Windows itself before the card is involved; once
   the card is, there may be no desktop left to watch a failure on.

2. Shut it down, then edit it with `virsh -c qemu:///system edit windows`.

   First, make the machine report some hypervisor other than Hyper-V. libvirt
   advertises Hyper-V to every Windows guest, because Windows runs better with
   its enlightenments, and AMD's graphics driver looks for exactly that and
   locks the machine up the moment it loads. Inside the existing `<hyperv>`
   element, add:

   ```xml
   <vendor_id state='on' value='randomid'/>
   ```

   The rest goes inside `<devices>`. Find the card's PCI address, and that of
   its audio function, which is the same address ending in `.1`:

   ```sh
   lspci -Dnn -d ::0300
   ```

   Add both as host devices, with `managed='no'` so that libvirt leaves the
   driver work to the hook. For a card at `0000:01:00.0`:

   ```xml
   <hostdev mode='subsystem' type='pci' managed='no'>
     <source>
       <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
     </source>
   </hostdev>
   <hostdev mode='subsystem' type='pci' managed='no'>
     <source>
       <address domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
     </source>
   </hostdev>
   ```

   Give the machine the keyboard and the mouse, since the desktop that would
   have relayed them will be gone, or on another screen. They are listed by
   name under `/dev/input/by-id/`; take the keyboard's `event-kbd` entry and
   the mouse's `event-mouse` one. QEMU holds them for Windows while the machine
   runs and lets go when it stops; pressing both Shift keys at once hands them
   to the other side in the meantime. Shift rather than the default Ctrl,
   because both systems swap Ctrl with Caps Lock, and the first key of the
   pair reaches whichever side has the keyboard before the toggle fires:

   ```xml
   <input type='evdev'>
     <source dev='/dev/input/by-id/usb-KEYBOARD-event-kbd' grab='all' grabToggle='shift-shift' repeat='on'/>
   </input>
   <input type='evdev'>
     <source dev='/dev/input/by-id/usb-MOUSE-event-mouse'/>
   </input>
   ```

   Remove the emulated display: the `graphics` element, the `video` element,
   and the Spice `channel` and `redirdev` elements that exist only for it.
   Left in, Windows makes the emulated display its main screen and puts
   nothing useful on the monitor.

3. Start it with `windows start`. The terminal that was typed in vanishes with
   the desktop; that is the hook stopping the login manager, and the start
   carries on without it. The monitor then shows the
   firmware, then Windows on its basic display driver. Install the card
   maker's own driver package at that point, once; from then on Windows drives
   the card itself, with the card's full memory aperture. Do this after the
   step above, not before: a driver that loads without the changed identifier
   locks Windows up mid-installation, and the half-installed result has to be
   removed from Safe Mode before anything works again.

   Then, from Linux, `windows postinstall`. A USB disc appears in Windows
   holding the same French (QWERTY) layout as Linux, in the form Microsoft's
   Keyboard Layout Creator builds into an installable layout, a registry file
   that swaps Caps Lock and Ctrl, and a text file with the steps, which the
   command prints as well. The disc is gone at the next shutdown; run the
   command again if it is needed again.

   If instead the login screen comes straight back, the start failed after
   the hook had done its part, and `journalctl -k` says why. One cause with a
   known cure: `Firmware has requested this device have a 1:1 IOMMU mapping`
   means the firmware's Kernel DMA Protection is on, and it refuses every
   device on the first PCI buses to VFIO until that is turned off in the BIOS.

4. Shut Windows down from inside Windows, or with `windows stop`, which asks
   Windows the same thing through ACPI. Once the machine has stopped, the hook
   hands the card back to its driver and restarts the login manager, so the
   card is the desktop's again. A machine that no longer answers can be
   stopped with `windows kill`; the hook gives the card back all the same,
   with a reset if it has to, and that has recovered cleanly here, but for
   Windows it is a power cut. `windows status` says whether the machine is
   running, and `journalctl -t passthrough` shows every step the hook took.

## Verifying the images

Images are signed as they are published, and the image carries the policy that
enforces it, so verification is not something you run — `bootc upgrade` refuses
an image not signed by the key in
[`rootfs/etc/pki/containers/yellowtail.pub`][pubkey].

To check by hand, copy the image on a machine already running Yellowtail, which
applies that same policy:

```sh
sudo skopeo copy docker://ghcr.io/xiu-heng-hua/yellowtail:latest dir:/tmp/verify
```

Note that `cosign verify` will report no signature. Signing is done by `skopeo`
for the reason given under "Signature verification needs three files, not one".

If you fork this, generate your own pair before the first build. `cosign` is
used only to create the key; signing is done by `skopeo`:

```sh
pass=$(head -c 32 /dev/urandom | base64 | tr -d '\n')
podman run --rm --user 0:0 -e COSIGN_PASSWORD="$pass" \
  -v .:/work:z -w /work \
  gcr.io/projectsigstore/cosign:v2.6.1 generate-key-pair
gh secret set SIGNING_KEY < cosign.key
printf '%s' "$pass" | gh secret set SIGNING_PASSPHRASE
shred -u cosign.key
```

The private key exists on disk between those commands, which cosign's
`github://` provider would avoid — but that provider names the secrets itself,
and a secret cannot be renamed later because its value cannot be read back.

Then move `cosign.pub` to [`rootfs/etc/pki/containers/yellowtail.pub`][pubkey]
and commit it. [`build.sh`][build] fails without it, because an image whose
policy names a key it does not ship cannot be upgraded.

## Building locally

```sh
podman build --tag yellowtail .
```

The build ends with `bootc container lint`, so a build that succeeds is a valid
bootable container.

## Building an installer ISO

To install onto a machine that is not already running an atomic Fedora, build an
Anaconda ISO from the published image and write it to a USB stick:

```sh
mkdir -p output
sudo podman pull ghcr.io/xiu-heng-hua/yellowtail:latest
sudo podman run --rm -it --privileged \
  --security-opt label=type:unconfined_t \
  --volume /var/lib/containers/storage:/var/lib/containers/storage \
  --volume ./output:/output \
  ghcr.io/osbuild/bootc-image-builder:latest \
  build --type anaconda-iso --output /output --chown "$(id -u):$(id -g)" \
  ghcr.io/xiu-heng-hua/yellowtail:latest
```

Both preparatory steps matter: `output` must exist, because podman will not
create a missing volume source and fails with `statfs ... no such file or
directory`, and the container must already be in root's storage.

The ISO lands in `output/bootiso/`. It embeds the image, so the installation
needs no network, and it runs the ordinary Anaconda installer: partitioning and
the user account are set up interactively, which is why the image contains no
user of its own.

Root is created as btrfs, declared by
[`rootfs/usr/lib/bootc/install`][install-cfg]. Without that the installer has no
filesystem type to use and one has to be passed on the command line.

`bootc-image-builder` is deprecated in favour of `image-builder` and is
discontinued in RHEL 11, but it is still what builds this. `image-builder`
rejects `anaconda-iso` outright, and its replacement type, `bootc-installer`,
takes two containers: `--bootc-installer-payload-ref` for the system being
installed, and `--bootc-ref` for an installer environment you are expected to
build yourself. That is a project rather than a flag change, so migrating waits
until there is a reason to own an installer image.

## Layout

```
Containerfile   the image
build.sh        repositories, packages, generated files
rootfs/         files copied into the image as-is
.github/workflows/build.yml
                nightly build, push and sign
```

Changing what the image contains means editing [`build.sh`][build] or adding a
file under `rootfs/`.

## Why the image looks like this

Everything below is a decision that is not obvious from the code, and that
something else will silently break if it is undone.

### Ghostty is the only terminal, and that takes two packages

GLib picks the terminal for a `Terminal=true` desktop entry from a list compiled
into `libgio`: `xdg-terminal-exec`, `ptyxis`, `gnome-terminal`, `mate-terminal`,
`xfce4-terminal`, `tilix`, `konsole`, `nxterm`, `color-xterm`, `rxvt`, `dtterm`.
Ghostty is not on it and cannot be added.

`xdg-terminal-exec` is first on that list, and it selects by the
`TerminalEmulator` category instead — which is how Ghostty gets chosen. Removing
`ptyxis`, which [`build.sh`][build] does with `dnf swap`, leaves exactly one
such entry, so the choice is unambiguous.

Neither works alone. Drop `xdg-terminal-exec` and GLib walks its list, finds
nothing installed, and terminal launching fails silently. Nothing in the image
currently ships a `Terminal=true` entry, so the failure would not appear until
something did.

### The Firefox preference file must sort first

Fedora sets a start page and a pinned tile in
`/usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js`.
Firefox reads every `.js` in that directory in **descending** filename order,
and the last file read wins. A `zz-` prefix loses; `00-` wins, which is why the
override is
[`rootfs/usr/lib64/firefox/browser/defaults/preferences/00-yellowtail.js`][ff-prefs].

That file overrides those two preferences only. Fedora's other thirty or so are
deliberately kept, including the one that disables Firefox's own updater — the
image manages Firefox, so Firefox must not.

### The bookmarks are not a preference

Fedora's bookmarks live inside `omni.ja`, which Firefox loads as
`chrome://browser/content/default-bookmarks.html`. No preference reaches them,
and removing the `fedora-bookmarks` package does not either: that package is a
build-time input whose file is already copied into the archive, and nothing in
Firefox reads `/usr/share/bookmarks` at runtime.

[`rootfs/usr/lib64/firefox/distribution/policies.json`][ff-policies] sets
`NoDefaultBookmarks` instead, which is the documented way to stop them being
created. It applies when a profile is created, so a machine with an existing
Firefox profile keeps whatever that profile already holds.

### The keyboard layout cannot be called `custom`, or `fr`

The layout is [`rootfs/etc/xkb/symbols/fr-qwerty`][xkb-symbols]. Both of the
names it would naturally take are already spoken for, in different ways.

`custom` is the name
[xkeyboard-config](https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config)
reserves for exactly this, and it declares it:
`/usr/share/X11/xkb/rules/evdev.xml` describes `custom` as "A user-defined
custom Layout", short description `custom`, no language. That entry is what
GNOME reads, so the panel says `custom` and the layout counts as language `und`.
A drop-in cannot correct it —
[libxkbregistry](https://xkbcommon.org/doc/current/) merges every
`rules/evdev.xml` on its include path, but the first definition of a name wins,
and the packaged one is a definition.

`fr` with a `qwerty` variant is what this layout actually is, and it is worse.
Resolving `fr(qwerty)` sends xkbcommon looking for a symbols file named `fr`,
and the first one on the include path answers the whole request — so a file in
`/etc/xkb/symbols` shadows the packaged `fr` instead of extending it, and every
stock French variant stops compiling. A rules drop-in does not rescue it either:
rule values beginning with `+` append rather than replace, and the packaged
catch-all for the second and later layout positions is `+%l[N]%(v[N]):N`. In
first position a custom rule wins, but from second position the packaged rule
appends `+fr(qwerty):2` beside it, the keymap fails to compile, and the keyboard
drops back to US without saying so.

So the layout carries its own name, which the packaged rules resolve unaided at
every position. [`rootfs/etc/xkb/rules/evdev.xml`][xkb-registry] then supplies
what a name alone does not: the short description `fr` that GNOME shows, and
`fra`, which is how anything asking what language this keyboard types gets an
answer. It sits under `/etc/xkb` because that is the only include path the image
can add a registry file to — the packaged `rules/evdev.xml` has no drop-in
directory beside it. Its elements are in DTD order, `countryList` before
`languageList`; reversed, the file fails validation and is discarded whole, and
the layout simply never appears in Settings.

### Virtual machines arrive without their state directories

`virt-manager` pulls libvirt, QEMU and `edk2-ovmf` by itself, and the modular
libvirt sockets are enabled by the packages, so nothing needs switching on. UEFI
firmware matters here: testing an installer ISO means booting it the way real
hardware would.

What the packages cannot bring is their own state. They own directories under
`/var`, and an image seeds `/var` only on a fresh installation, so a machine
that arrived by `bootc switch` has none of them. [tmpfiles][tmpfiles] creates
them at the modes the packages use. The one that matters most is
`/var/lib/libvirt/images`, the default storage pool: without it no virtual
machine can be created at all.

Every one of them is listed, including those a daemon would recreate by itself.
`bootc container lint` warns about any directory left in the image's `/var`
without a tmpfiles entry, and the directories libvirt drags in reach further
than libvirt: `swtpm` for emulated TPMs, and `iscsi-initiator-utils`, which
arrives with the iSCSI storage driver and recreates nothing at all.

`rpm` also makes `/var/lib/rpm-state` while `dnf` works, and that is scratch
rather than state. [`Containerfile`][containerfile] mounts a tmpfs over it for
the length of the build, next to the ones over `/var/cache`, `/var/lib/dnf` and
`/var/log`, so nothing written there reaches the image and there is nothing to
declare.

Connecting to the system libvirt asks for an administrator password unless the
account is in the `libvirt` group. That is a per-machine change, so no image can
make it:

```sh
sudo usermod -aG libvirt "$USER"
```

### A passed-through card is taken at start time, from whoever holds it

Software that computes on the GPU wants a real card behind a real Windows
driver, and nothing that shares a card with the host, be it Wine, a paravirtual
GPU or a streamed desktop, provides that. Passing a card through means the host
has to let go of it first.

The usual set-up binds the card to `vfio-pci` at boot, with a kernel argument,
so that the host never touches it. That needs a second GPU for the desktop and
loses the card to Linux entirely. So [the hook][hook] does the hand-over when
the machine starts, and takes the card from whoever holds it then. When nothing
does, because the card was bound to `vfio-pci` at boot and another GPU carries
the desktop, the desktop is left alone. When the desktop holds it, the desktop
is stopped: GNOME on Wayland opens every GPU it can see and never lets one go,
so there is no taking a card from a running desktop. If a display device
remains, the login manager is started again at once and the desktop comes back
on that one; when the machine stops, it is restarted once more, so that the
returned card is the desktop's primary GPU again. Linux stays up underneath in
every case, and awake: for as long as the machine has the devices, the hook
holds a sleep inhibitor, because the login screen it leaves behind suspends an
idle computer after a quarter of an hour, a keyboard and mouse held by Windows
count as idle, and a host asleep under a running machine takes the card down
with it.

libvirt runs every executable in `/etc/libvirt/hooks/qemu.d/` at each step of
every machine's life, as root, with the machine's name and the step as
arguments and the machine's definition on standard input, and waits for it.
The hook reads the PCI host devices marked `managed='no'` out of that
definition, so nothing about the hardware is written into the image, and acts
on two steps. At `prepare`, before libvirt allocates anything, it stops the
login manager if any process holds one of the devices, detaches each device's
driver, remembering which, and attaches `vfio-pci`; if any of that fails, it
undoes what it did and exits non-zero, which makes libvirt refuse to start the
machine. At `release`, once the machine has stopped, it does the reverse in
reverse order and restarts the login manager if it had stopped it, and nothing
on that path stops at an error, since libvirt no longer cares and the desktop
has to come back regardless. What `prepare` learns for `release` it leaves
under `/run/libvirt`, which is emptied at boot, and a second `prepare` for the
same machine leaves that record alone rather than starting over, so that a
stray copy of the hook in the same directory cannot make the release forget
what to give back. The hook never calls `virsh`: libvirt is waiting for it,
and that would deadlock.

Stopping the login manager ends the graphical session, but its programs take a
moment to go, and a driver must not be pulled from under one. The hook finds
them by their open handles to the devices' nodes in `/proc`, gives them ten
seconds, then terminates them: nothing that outlives the desktop can show
anything. A text console bound to the card would hold the driver too, and is
unbound first.

The rest is what the cards want. Every device is kept out of its deepest power
state while no driver holds it, or it powers down between the two drivers and
the second one cannot wake it. Drivers are chosen with `driver_override` and
bound by address, and the override is cleared afterwards by writing a lone
newline, because a write of nothing at all never reaches the kernel. On the way
back each driver is given five tries, with a reset of the device after the
third, before the desktop is restarted anyway. And the host devices carry
`managed='no'`: with `managed='yes'`, libvirt would hand the card back by
itself, by asking the kernel to pick a driver, before the hook can restore the
card's power settings, and by a route that does not always work.

Nothing is done to the card's memory regions. Advice from 2025 has AMD's
Windows driver refusing a card whose regions were not shrunk first, and this
hook did that for a while; what the driver was refusing turned out to be the
Hyper-V that libvirt advertises, and with the identifier changed as the Windows
section says, the driver takes the full aperture and enables Smart Access
Memory. A card the desktop had been using, a card handed over straight from
boot, and a card the host had been putting to sleep in each of amdgpu's two
ways all worked once that was fixed.

### Windows gets its keyboard on a disc

The keyboard reaches Windows as raw key presses through evdev, so the layout
Linux applies never applies inside; Windows needs its own. Microsoft's
Keyboard Layout Creator builds one from a text description, and
[`fr-qwerty.klc`][klc] is that description, written from the xkb symbols key
for key, with the same four dead keys and the same characters under AltGr.
The two files describe one layout and change together; xkb stays the one the
desktop reads. Caps Lock swapped with Ctrl is not a layout matter on Windows
but a scancode remap in the registry, so it travels as a [registry
file][reg]. Neither can be applied from Linux, so they are handed over the
way Windows expects settings from outside: on a disc.

[`build.sh`][build] turns the directory into that disc with `xorriso`, which
the image has already because virt-manager needs it. The layout tool wants
its input in UTF-16 with Windows line endings, and the registry editor is
happiest with the same, so the build converts both on the way and leaves the
sources in the repository as plain text. `windows postinstall` copies the disc
into libvirt's storage pool the first time, under a name derived from its
content so that a changed disc gets a fresh copy, and hot-plugs it into the
running machine as a USB drive. The copy exists because QEMU is only allowed
to read files libvirt has labelled, and libvirt cannot label anything on the
read-only image. A hot-plugged drive is not written into the definition, so
it disappears at the next shutdown, which is what a settings disc should do.

### SELinux does not let libvirt run QEMU hooks

Fedora's policy labels hook scripts `virt_hook_t` and has a boolean,
`virt_hooks_unconfined`, described as "allow virt daemons run unconfined
hooks". But the rules behind the boolean only name `virtnetworkd`, the network
daemon. QEMU machines are run by `virtqemud`, which is allowed to read a
`virt_hook_t` file and not to execute it, boolean or no boolean, so with
SELinux enforcing a QEMU hook never starts, and neither does the machine.

[`yellowtail_virt_hooks.cil`][cil] adds for `virtqemud` exactly the rules the
policy has for `virtnetworkd`, under the same boolean: leave to execute the
script, and to transition into `virt_hook_unconfined_t`, the unconfined domain
the policy already defines for hooks. Unconfined is what the hook needs, since
it stops and starts a systemd unit and rebinds drivers through sysfs.
[`build.sh`][build] installs the module and turns the boolean on.

Both commands run with `--noreload`. They normally rebuild the policy and load
it into the running kernel, and a container build has no kernel to load it
into. The rebuild is what matters: on an image-based system the policy store
lives under `/etc/selinux` (on the running machine, `/var/lib/selinux` is a
link to it), precisely so that a rebuilt policy ships with the image and is
what the machine boots with. `libsemanage` also keeps a copy of the previous
store beside it, seventeen megabytes no build needs, and that is removed.

### Desktop defaults are schema defaults, not anyone's dconf

The layout, the Caps Lock swap and the wallpaper are set in
[`zz-yellowtail.gschema.override`][gschema], which changes what the schema
*defaults* to. Writing them into a dconf database instead would either be
per-account, and so miss every account made later, or locked, and so refuse to
be changed at all. As defaults they apply to any account, including ones made
years from now, and the first change in Settings still wins permanently.

`glib-compile-schemas` reads every `.override` in the directory in filename
order and the last one read wins, so the `zz-` prefix puts this after
`10_org.gnome.desktop.background.fedora.gschema.override`, which is what
otherwise sets the Fedora wallpaper. Nothing reads the file itself at runtime:
[`build.sh`][build] compiles it into `gschemas.compiled`, and without that step
the file is inert.

`xkb-options` is one list for the whole keymap rather than a setting per layout,
so the Caps Lock swap holds for Mozc too. The screensaver section sets only
`picture-uri`, because `org.gnome.desktop.screensaver` has no `picture-uri-dark`
key — Fedora's own override sets one, and glib prints a warning and ignores it.

### The virtual consoles need a keymap of their own

A console keymap is a `kbd` table, not an XKB layout, so nothing in `/etc/xkb`
reaches a virtual console. [`build.sh`][build] converts one to the other with
`ckbcomp`, from `console-setup`, which it installs and removes in the same step
so the tool does not ship in the image.

The table is generated rather than committed because a committed copy would
drift from [the symbols file][xkb-symbols] the moment either changed. The Caps
Lock swap is baked into it, since [`vconsole.conf`][vconsole] names a keymap and
has nowhere to put an XKB option.

### `--allowerasing` is about a conflict, not a dependency

Nothing requires `ffmpeg-free`, but [RPM Fusion](https://rpmfusion.org/)'s
`ffmpeg-libs` declares a hard `Conflicts` with the installed `libswscale-free`
and `libavcodec-free`. The swap in [`build.sh`][build] cannot resolve without
permission to erase them.

The Ptyxis swap declares no such conflict and resolves on its own, which is why
only one of the two carries the flag.

### Where repository keys come from

The RPM Fusion keys are imported in [`build.sh`][build] from
`distribution-gpg-keys`, which is already in the base image, so the release
packages fetched over the network are verified against a key that was not.
[Terra](https://terra.fyralabs.com/) cannot work this way: its key ships inside
`terra-release` itself, so that one package is installed with `--nogpgcheck` and
everything from Terra after it is verified.

Terra provides Ghostty, and [`build.sh`][build] removes `terra-release` once it
is installed. Its `.repo` file points at a key with `file://`, which resolves
only inside this image, so anything depsolving against these repository files
from outside — the ISO builder does — cannot read it. Fedora and RPM Fusion use
`file://` keys too and survive that, because a build host already has those keys
and does not have Terra's.

Removing the package rather than disabling the repository is deliberate: `dnf
config-manager setopt` records the change in `/etc/dnf/repos.override.d/`,
leaving `enabled=1` in the file itself, and tools that read `/etc/yum.repos.d`
directly go on believing the repository is live.

[`rootfs/etc/yum.repos.d/claude-code.repo`][claude-repo] sets `repo_gpgcheck=1`
as well as `gpgcheck=1`. They are not the same check: `gpgcheck` verifies the
packages, and `repo_gpgcheck` verifies the repository metadata that says which
packages exist. That repository signs its metadata, so both are checked.

### Terra is reached by its baseurl, not its metalink

`terra-release` configures the repository with a metalink, and in August 2026
that metalink began advertising a `repomd.xml` checksum none of Terra's mirrors
serve. Every mirror is consistent with itself and none matches what the metalink
asks for, so `dnf` rejects the repository and the build fails with `No match for
argument: ghostty`. [`build.sh`][build] therefore clears the metalink and points
the repository at its baseurl. That costs the mirror list and buys a build that
does not depend on Terra's metalink agreeing with Terra's mirrors.

### Signature verification needs three files, not one

Shipping [`rootfs/etc/pki/containers/yellowtail.pub`][pubkey] and a
[`rootfs/etc/containers/policy.json`][policy] that requires `sigstoreSigned` is
not enough. `use-sigstore-attachments` must also be set in
[`rootfs/etc/containers/registries.d/yellowtail.yaml`][registries], or the
tooling never looks for the signature and verification fails with a message that
does not mention it.

`policy.json` keeps the base image's `insecureAcceptAnything` default, because
everything else pulled on this machine — toolbox images, containers you build —
is unsigned and must stay pullable. The consequence is that the repository named
under `transports.docker` is load-bearing: if it does not match the image
actually pulled, as after a fork or a rename, the default applies and the image
is accepted **without** verification rather than rejected. A fork must change
that path, the one in `registries.d`, and the key, together.

`signedIdentity` is `matchRepository` because CI signs the digest while you pull
a tag; the default would require the signature to name the exact tag.

The push step in [`.github/workflows/build.yml`][workflow] signs with
[skopeo](https://github.com/containers/skopeo) rather than
[cosign](https://github.com/sigstore/cosign). Against a registry that supports
the OCI 1.1 referrers API, which GHCR does, cosign attaches the signature as a
referrer, and the policy above reads only the older `sha256-<digest>.sig` tag.
The result is an image that looks signed and cannot be verified. skopeo signs
through the same library that verifies, so the two agree.

### Nothing rechunks the image

This repository used to run `rpm-ostree compose build-chunked-oci` over the
built image, splitting it into package-aligned layers so an update would carry
only what changed. It never did that. The layer plan is rebuilt from scratch
unless `--previous-build` supplies a baseline, and that flag could not take
effect: `build-chunked-oci` marks each layer it writes with an
`ostree.components` annotation and looks for that annotation to recognise its
own output, but pushing from `containers-storage` recompresses every layer, and
the manifest skopeo writes in place of the original carries no layer annotations
at all. Every build logged `Found existing image at target but it's not chunked`
and started over. Measured across consecutive published tags, 41 to 44 of 65
layers changed nightly — about three quarters of the image.

Without it the image is the base image's layers plus one holding everything
[`build.sh`][build] adds. Those layers are not the ones Fedora published —
pushing from `containers-storage` recompresses every one of them, so none of the
digests survive — but they are stable from build to build: two builds from an
unchanged base share 65 of 66 layer digests. Only the layer this repository adds
changes nightly. It also removes a privileged container, a bind mount of the
host's container storage, and a permissive `policy.json` mounted over the
image's own.

### The runner's container storage has to be reconfigured

GitHub's runner image points podman's overlay driver at fuse-overlayfs, a
userspace implementation, by setting `mount_program` in
`/etc/containers/storage.conf`. Every file operation on an image of a hundred
thousand files then goes through FUSE, and two things follow. A build takes
thirty-five minutes rather than five. And the rpm database comes out of the
layer corrupt: pages of an index return `btreeInitPage() returns error code 11`
and `rpm -qa` stops partway through, which is [a known fuse-overlayfs
bug][fuse-459]. The database is sound at the end of [`build.sh`][build] and
broken when read back from the committed image.

[`build.yml`][workflow] therefore deletes `mount_program`, along with the
`mountopt` line whose `fsync=0` means nothing to the kernel's overlayfs, from
whichever of podman's two configuration files the runner has: the one under
`/etc`, which the runner image shipped until early September 2026 and then
stopped, and the package's own under `/usr/share`. A file that is not there is
left alone; editing it unconditionally is what took the nightly build down
for four days. The step also removes `/var/lib/containers/storage`, because
podman records its options when it first initialises the store: editing the
file after any podman command has run changes nothing at all, which is easy to
miss and looks exactly like the change having no effect.

Reading the database back and failing on `pragma integrity_check` is the step
after the build. Nothing else in the pipeline reads it, so without that check a
return of the corruption would be found on the machine rather than in the build.
A build on any other machine configured the same way is affected in the same
way, and nothing there checks at all.

[`build.sh`][build] still takes the database out of WAL mode at the end, which
drops the `-shm` index that a read-only `/usr` could not recreate. That is
tidiness, not a fix.

### Preinstalled Flatpaks have to be asked for

`flatpak preinstall` reads
[`rootfs/usr/share/flatpak/preinstall.d/yellowtail.preinstall`][preinstall] and
installs what it names. Nothing on Fedora runs it, despite
`flatpak-preinstall(1)` saying the OS does so at startup, so a new machine needs
the command run by hand once.

It uninstalls only refs it installed itself and which have since left the
config. Applications installed by hand are never marked and never touched, and
uninstalling a preinstalled one is a permanent opt-out.

The applications themselves are not in the image, and never were: on Silverblue
the GNOME set arrives as Fedora Flatpaks placed by the installer, which is why a
machine reaching this image through `bootc switch` keeps them and a fresh
installation has none. The set is eighteen applications, listed as
`flatpak_remote_refs` under `^Silverblue$` in [pungi-fedora's
`fedora.conf`][pungi]. Six of them are not really applications you choose but
parts of the desktop shipped separately — Sushi is what Files calls for the
spacebar preview, and Extensions, Characters, Fonts, Image Viewer and Document
Viewer are the only graphical way to reach what they cover — so those six are
named in the config and the other twelve are left out.

### Which remote a preinstall comes from is decided by name

A `.preinstall` group names a ref, never a remote: the only keys are `Install`,
`Branch`, `IsRuntime` and `CollectionID`. Flatpak walks the enabled remotes in
order and takes the first one carrying the ref, and that order is by priority
first, then `strcmp` on the name. Both remotes here sit at the default priority
1, so `fedora` sorts before `flathub` and wins every tie.

It only matters for refs both remotes carry, which is exactly the six GNOME
applications: they arrive as Fedora Flatpaks on `org.fedoraproject.Platform`
rather than the Flathub builds on `org.gnome.Platform`. Bitwarden, Discord,
Thunderbird and Gear Lever are on Flathub alone and are unaffected. Pinning the
Flathub build would mean giving that remote a collection ID and naming it with
`CollectionID`, or raising its priority above `fedora`; neither is done, because
the Fedora build of a GNOME application tracks the same release as the shell.

Thunderbird is on Flathub alone only by name: `fedora` carries the same
application as `net.thunderbird.Thunderbird`, so `org.mozilla.thunderbird` names
the build MZLA publishes and nothing else. Renaming the ref to match upstream's
identifier would silently hand it to `fedora`.

That remote is not configured here. `flatpak-add-fedora-repos.service`, shipped
and enabled by the `flatpak` package itself, adds `fedora` and a disabled
`fedora-testing` on first boot, then drops
`/var/lib/flatpak/.fedora-initialized` so it never runs again.

### Flatpak permissions come through tmpfiles

Flatpak reads system-wide overrides from `/var/lib/flatpak/overrides/`, and
`/var` is machine-local on bootc, so the image cannot write there.
[`rootfs/usr/lib/tmpfiles.d/yellowtail.conf`][tmpfiles] bridges it: the `C` line
copies the default across on first boot and then leaves it alone, so `flatpak
override` still works and survives updates. Changing a default in a later image
therefore does not reach a machine that already has the file; delete it and
reboot to take the new one.

The `C` line names no source, which makes systemd read `/usr/share/factory/`
followed by the destination path. That is why the file sits at
`usr/share/factory/var/lib/flatpak/overrides/` — the copy is described by where
the file is rather than by an argument.

Discord needs this because drag-and-drop hands an application a path rather than
a file descriptor. File dialogs go through a portal and work whatever the
permissions are; drops do not, and fail silently outside the sandbox.

### The Flathub key is pinned, not fetched

[`rootfs/usr/share/flatpak/remotes.d/flathub.flatpakrepo`][flathub] is Flathub's
own repository definition, downloaded once from
`https://dl.flathub.org/repo/flathub.flatpakrepo` and committed. It carries the
key that signs everything installed from Flathub, so fetching it during the
build would mean trusting whatever that host returned on the night of each
build; pinning it means the trusted key is reviewable in git and changes only in
a commit.

The key is `6E5C05D9 79C76DAF 93C08135 4184DD4D 907A7CAE`, RSA 4096, and it
**expires on 2027-06-14**. After that Flatpak cannot verify the remote until
this file is replaced with a current one.

### No update timer is enabled, and none is needed

`bootc-fetch-apply-updates.timer` and `rpm-ostreed-automatic.timer` are both
disabled, which makes it look as though nothing updates the system. GNOME
Software does: it runs as a user service, asks `rpm-ostreed` for a new image and
stages it. Enabling a timer as well would mean two things pulling the same
image.

### Homebrew ships as a tarball, and its units need enabling by hand

Homebrew cannot be installed during the build. It lives in `/home/linuxbrew`,
which is `/var`, and `/var` in an image only seeds a fresh installation — a
machine that arrives by `bootc switch` would never see it. The image therefore
carries `usr/share/homebrew.tar.zst` from `ghcr.io/ublue-os/brew`, and
`brew-setup.service` unpacks it on first boot.

That image is tracked by tag rather than digest, so it can change between
builds.

It also ships `brew-update.timer`, which refreshes the formula index every six
hours, and `brew-upgrade.timer`, which upgrades installed packages every eight.
All three units are enabled.

`01-homebrew.preset` asks for exactly those three, but a preset is only a policy
file and nothing in this build applies it — copying the files enables nothing,
which is why [`build.sh`][build] enables them explicitly.

`brew doctor` warns that `/home` is a symlink, because on an ostree system it
points at `/var/home`. Moving the prefix would not fix it and would cost far
more: `/home/linuxbrew/.linuxbrew` is baked into every bottle, so anywhere else
means building each formula from source. The warning is expected here.

### Homebrew wants a compiler, not Fedora's developer group

Homebrew's Linux requirements ask for a working system C compiler and the
standard development tools, and note that the gcc it installs for itself does
not replace the system one used for bootstrap and post-install steps. The Fedora
instruction it gives is `dnf group install development-tools`, and that group is
the wrong thing here: it is Fedora's version control and documentation
collection — Subversion, SystemTap, Doxygen, 238 packages and 169 MiB — and it
carries no compiler at all.

Silverblue ships git, curl, file and procps-ng, but no compiler and no `make`:
on an ordinary Fedora those arrive behind something else, and a base image has
no such something else. So [`build.sh`][build] asks for `gcc`, `make` and
`patch`, which bring binutils and the libc headers behind them — eight packages,
52 MiB — and stops there.

What brew tests for is `clang` or `gcc` and nothing besides, so no C++ compiler
is installed: it would cost another 88 MiB for something brew never asks after.
`patch` is a separate requirement, applied rather than tested — brew shells out
to it by name whenever a formula carries a patch. Autotools are left out on the
same principle as C++. Formulae needing them declare them as formulae, and brew
installs those itself; the system compiler is the one thing it cannot.

### The Fedora version is not a build argument

[`build.sh`][build] derives it with `rpm -E %fedora`, so it cannot drift from
the tag in [`Containerfile`][containerfile]. Upgrading to a new release means
editing the `FROM` line.

## License

[MIT](LICENSE)

[build]: build.sh
[cil]: rootfs/usr/share/selinux/packages/yellowtail_virt_hooks.cil
[claude-repo]: rootfs/etc/yum.repos.d/claude-code.repo
[containerfile]: Containerfile
[ff-policies]: rootfs/usr/lib64/firefox/distribution/policies.json
[ff-prefs]: rootfs/usr/lib64/firefox/browser/defaults/preferences/00-yellowtail.js
[flathub]: rootfs/usr/share/flatpak/remotes.d/flathub.flatpakrepo
[fuse-459]: https://github.com/containers/fuse-overlayfs/issues/459
[gschema]: rootfs/usr/share/glib-2.0/schemas/zz-yellowtail.gschema.override
[hook]: rootfs/etc/libvirt/hooks/qemu.d/passthrough
[install-cfg]: rootfs/usr/lib/bootc/install
[klc]: rootfs/usr/share/yellowtail/windows/fr-qwerty.klc
[packages]: https://github.com/xiu-heng-hua/yellowtail/pkgs/container/yellowtail
[policy]: rootfs/etc/containers/policy.json
[preinstall]: rootfs/usr/share/flatpak/preinstall.d/yellowtail.preinstall
[pubkey]: rootfs/etc/pki/containers/yellowtail.pub
[pungi]: https://forge.fedoraproject.org/releng/pungi-fedora/src/branch/f44/fedora.conf
[reg]: rootfs/usr/share/yellowtail/windows/swap-caps-ctrl.reg
[registries]: rootfs/etc/containers/registries.d/yellowtail.yaml
[tmpfiles]: rootfs/usr/lib/tmpfiles.d/yellowtail.conf
[vconsole]: rootfs/etc/vconsole.conf
[windows-cmd]: rootfs/usr/bin/windows
[workflow]: .github/workflows/build.yml
[xkb-registry]: rootfs/etc/xkb/rules/evdev.xml
[xkb-symbols]: rootfs/etc/xkb/symbols/fr-qwerty
