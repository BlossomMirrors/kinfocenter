# kinfocenter (BlossomOS patches)

BlossomOS-specific patches for KInfoCenter, published to [repo.blossomos.org/rpm](https://repo.blossomos.org/rpm/).

Rather than carrying a full fork of KInfoCenter, this repo just holds a small patch series applied on top of Fedora's stock `kinfocenter` package.

## Usage

```
./build.sh [fedora_version]
```

Defaults to `rawhide`. Pass a Fedora release number (e.g. `44`) to build against that release's `kinfocenter` instead. The built RPMs land in `build/rpmbuild/RPMS/`.

The script fetches the latest `kinfocenter` SRPM from Koji, caches it in `cache/` to avoid re-downloading, strips any mbox email headers from patch files, injects the patch declarations into the spec, installs build dependencies via `dnf builddep`, and runs `rpmbuild`.

## Installing locally

```
./install.sh [fedora_version]
```

Builds (forwarding any argument to `build.sh`), then overlays `/usr` with `rpm-ostree usroverlay` and installs the patched `kinfocenter` RPM directly into the live system for testing. The overlay is transient and resets on reboot.

## Adding patches

Drop `.patch` files into `patches/`. Files are applied in filename order, so prefix them with a zero-padded number (`0002-my-fix.patch`). Mbox-format patches (e.g. from `git format-patch`) work as-is.

## Patches

| # | Patch | Purpose |
|---|-------|---------|
| 0001 | About Distro: Serial Numbers section, PRETTY_NAME | Adds a Serial Numbers section (Machine ID from `/etc/machine-id`, Device ID derived from the primary MAC address) next to the existing system serial number, and switches the distro name/version display to `PRETTY_NAME` from os-release |
| 0002 | About Distro: allow changing the hostname | Adds a Device Name row with a Rename action that sets the static hostname via systemd-hostnamed over D-Bus (its own polkit prompt handles authorization) |
