# Maintaining nimf-overlay

Run local checks with:

```bash
./tests/run.sh
shellcheck scripts/*.sh tests/*.sh app-i18n/nimf/files/nimf-qt5.eselect
pkgcheck scan app-i18n/nimf
```

For the first publication, create the public repository, push `main`, and run
**Build Qt 5 SDK images**. When all four images are present in GHCR, run
**Update Nimf release** with version `1.4.19`. The update workflow builds both
architecture bundles, publishes a prerelease, regenerates the ebuild and
Manifest, runs the Gentoo build matrix, and opens a PR. Merge that PR only
after its required checks pass; the merge promotes the prerelease.

The SDK matrix is defined in `config/qt5-sdks.tsv` and duplicated explicitly
in the image workflow so a review shows every build input. When either changes,
the static tests require the two lists to remain in sync. Qt archive checksums
must come from `download.qt.io`.

To reproduce one plugin build after pulling an SDK image:

```bash
docker run --rm \
  -v "$PWD/upstream:/source:ro" \
  -v "$PWD/out:/output" \
  ghcr.io/june3474/nimf-overlay/qt5-sdk:5.13 \
  /source /output
```

Do not add a global `QT_PLUGIN_PATH`. Install plugins below the versioned Nimf
directory and let `eselect nimf-qt5` own the single system selector symlink.
