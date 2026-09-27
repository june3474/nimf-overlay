# nimf-overlay

Gentoo overlay for [hamonikr/nimf](https://github.com/hamonikr/nimf). GTK 3,
Qt 6 and Wayland support are built against Gentoo packages. Optional GTK 2,
GTK 4 and input engines are controlled with USE flags. The GTK 4 flag builds
the input method module; `nimf-settings` remains on GTK 3 because its current
source still uses GTK 3 APIs. Qt 5 plugins are built
in isolated SDK images because Gentoo no longer ships Qt 5.

## Install

```bash
eselect repository add nimf-overlay git https://github.com/june3474/nimf-overlay.git
emaint sync -r nimf-overlay
emerge --ask app-i18n/nimf
```

The default USE configuration builds GTK 2/3/4, Qt 6, Wayland, Hangul and the
Qt 5 compatibility plugins. `USE=-qt5` installs no Qt 5 schema, plugin,
selector module or global selector link.

Choose the Qt 5 minor used by applications that search Gentoo's system plugin
directory:

```bash
eselect nimf-qt5 list
eselect nimf-qt5 show
eselect nimf-qt5 set 5.13
```

The first install selects 5.15. Upgrades preserve the existing selection.
amd64 provides 5.11 through 5.15; arm64 provides 5.15. This does not require a
global `QT_PLUGIN_PATH`. An application with a private Qt plugin directory may
need a link to the matching versioned file in
`/usr/lib64/nimf/qt5/<minor>/platforminputcontexts/`.

Set these variables when starting a graphical session:

```text
GTK_IM_MODULE=nimf
QT_IM_MODULE=nimf
XMODIFIERS=@im=nimf
```

Hancom Office under `/opt/hoffice11` already carries a private Qt 5.11.3 Nimf
plugin. The package and selector never modify that file.

## Automation

The weekly workflow runs every Monday at 03:17 UTC (12:17 Korea time), detects
the latest stable upstream release, validates its source and Debian Bookworm
assets, builds Qt 5.11–5.14 in checksum-pinned SDKs, extracts Qt 5.15.8 from
Bookworm packages, and opens a tested PR. It never commits directly to the
default branch. Merging the PR promotes the corresponding prerelease.

See [CONTRIBUTING.md](CONTRIBUTING.md) for bootstrap and validation commands.
