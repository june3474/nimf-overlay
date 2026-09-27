# nimf-overlay

Gentoo overlay for [hamonikr/nimf](https://github.com/hamonikr/nimf).

nimf supports GTK 3, Qt 6 and Wayland by default. Other input engines like GTK 2, GTK 4 can be added optionally via USE flags. Because Gentoo no longer ships Qt 5, its plugins are built
and provided separately per version in isolated SDK image containers.\
`nimf-settings` is built against its
upstream source, currently GTK 3.

## What this overlay is for?

On **2026-06-30**, the Qt 5 packages were masked in Gentoo's
source tree. As a result, any Gentoo system synced after that date can no
longer build nimf's Qt 5 input module, causing the whole `nimf` build failure.

But Qt 5 applications are still in use, and nimf's Qt 5 input module is
still needed. This overlay provides a couple of ebuilds that lets you type and use Korean in Qt 5 applications via nimf, even on a Gentoo box where Qt 5
itself can no longer be installed after 2026-06-30.

## Install

```bash
eselect repository add nimf-overlay git https://github.com/june3474/nimf-overlay.git
emaint sync -r nimf-overlay
emerge --ask app-i18n/nimf
```

The default configuration builds and installs GTK 2/3/4, Qt 6, Wayland,
Hangul and the Qt 5 compatibility plugins. With `USE=-qt5`, the
Qt 5 plugins are not installed.

## Qt 5 support: why does need plugins per Qt 5 versions?

Qt 5's input plugins link against Qt5Core/Qt5Gui in ways
that are not guaranteed ABI-stable across minor releases. A plugin built
against Qt 5.11 headers and libraries is not guaranteed to load correctly
inside an application process linked against Qt 5.15, and vice versa —
there is no single binary that works for every 5.x minor version.

To work around this, this ebuild builds and installs one `platforminputcontexts` plugin per Qt 5 minor version, from 5.11 through 5.15. However, only one of them can be active as the systemwide default at a
time, so you have to choose which one applications should load with
`eselect`.

### eselect usage

```bash
eselect nimf-qt5 list
eselect nimf-qt5 show
eselect nimf-qt5 set 5.13
```

The first install selects 5.15 (the default). Upgrades preserve the
existing selection. amd64 provides 5.11 through 5.15; arm64 provides 5.15.
This does not require a global `QT_PLUGIN_PATH`.

> An application with a private Qt plugin directory may need
> a link to the matching versioned file in
> `/usr/lib64/nimf/qt5/<minor>/platforminputcontexts/`.

## Environment variables for graphical sessions

Set these when starting a graphical session so both GTK and Qt
applications route input through nimf:

```text
GTK_IM_MODULE=nimf
QT_IM_MODULE=nimf
XMODIFIERS=@im=nimf
```

## Automation

Every Monday at 03:17 UTC (12:17 Korea time), the workflow checks for the
latest stable upstream release of hamonikr/nimf; validates its source and Debian Bookworm assets; builds Qt 5.11–5.14 in checksum-pinned SDKs;
extracts Qt 5.15.8 from Bookworm packages; opens a tested PR; merges the PR promotes the corresponding prerelease.

> Because this check runs weekly rather than on every
> upstream commit, a new upstream release is **not** reflected
> here immediately — it can take a week or more to appear as a
> PR.

See [CONTRIBUTING.md](CONTRIBUTING.md) for bootstrap and
validation commands.
