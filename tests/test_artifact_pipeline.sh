#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fake_plugin="$tmpdir/libqt5im-nimf.so"
printf 'not-an-elf-test-fixture\n' >"$fake_plugin"

versioned_fixture="$tmpdir/versioned-plugin"
printf 'NIMF_QT_BUILD_VERSION=5.11.3\n' >"$versioned_fixture"
[[ $("$repo_root/scripts/qt-plugin-minor.sh" "$versioned_fixture") == 5.11 ]]

for version in 5.11 5.12 5.13 5.14 5.15; do
    mkdir -p "$tmpdir/plugins/$version"
    cp "$fake_plugin" "$tmpdir/plugins/$version/libqt5im-nimf.so"
done

SOURCE_DATE_EPOCH=0 "$repo_root/scripts/make-qt5-bundle.sh" \
    --nimf-version 1.4.19 \
    --upstream-commit 0123456789abcdef0123456789abcdef01234567 \
    --arch amd64 \
    --plugins-dir "$tmpdir/plugins" \
    --output "$tmpdir/bundle.tar.xz" \
    --skip-elf-check

mkdir "$tmpdir/unpacked"
tar -xJf "$tmpdir/bundle.tar.xz" -C "$tmpdir/unpacked"
manifest="$tmpdir/unpacked/manifest.sha256"
metadata="$tmpdir/unpacked/metadata.json"
[[ -f "$manifest" && -f "$metadata" ]]
python3 - "$metadata" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["nimf_version"] == "1.4.19"
assert data["upstream_commit"] == "0123456789abcdef0123456789abcdef01234567"
assert data["architecture"] == "amd64"
assert [item["qt_minor"] for item in data["plugins"]] == ["5.11", "5.12", "5.13", "5.14", "5.15"]
PY
(cd "$tmpdir/unpacked" && sha256sum -c manifest.sha256)
