#!/usr/bin/env bash
set -euo pipefail

output=${1:?Usage: discover-release.sh GITHUB_OUTPUT [VERSION]}
requested=${2:-}
upstream=${UPSTREAM_REPOSITORY:-hamonikr/nimf}
overlay=${OVERLAY_REPOSITORY:-june3474/nimf-overlay}

headers=(-H 'Accept: application/vnd.github+json')
if [[ -n ${GITHUB_TOKEN:-} ]]; then
	headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi
if [[ -n ${requested} ]]; then
	release_url="https://api.github.com/repos/${upstream}/releases/tags/v${requested}"
else
	release_url="https://api.github.com/repos/${upstream}/releases/latest"
fi
release=$(curl -fsSL "${headers[@]}" "${release_url}")
release_file=$(mktemp)
trap 'rm -f "${release_file}"' EXIT
printf '%s' "${release}" >"${release_file}"

python3 - "${output}" "${requested}" "${upstream}" "${overlay}" "${release_file}" <<'PY'
import json
import os
import pathlib
import sys

out, requested, upstream, overlay, release_file = sys.argv[1:]
data = json.loads(pathlib.Path(release_file).read_text())
if data.get("draft") or data.get("prerelease"):
    raise SystemExit("latest release is not a stable release")
tag = data["tag_name"]
version = requested or tag.removeprefix("v")
expected = {
    "amd64": f"nimf_{version}_amd64-debian.bookworm.deb",
    "arm64": f"nimf_{version}_arm64-debian.bookworm.arm64.deb",
}
assets = {item["name"]: item["browser_download_url"] for item in data.get("assets", [])}
missing = [name for name in expected.values() if name not in assets]
if missing:
    raise SystemExit("missing Bookworm release assets: " + ", ".join(missing))

root = pathlib.Path(os.environ.get("GITHUB_WORKSPACE", "."))
ebuild = root / "app-i18n" / "nimf" / f"nimf-{version}.ebuild"
manifest = root / "app-i18n" / "nimf" / "Manifest"
manifest_text = manifest.read_text() if manifest.exists() else ""
bundle_names = [f"nimf-qt5-plugins-{version}-{arch}.tar.xz" for arch in ("amd64", "arm64")]
complete = ebuild.exists() and all(name in manifest_text for name in bundle_names)

with open(out, "a", encoding="utf-8") as f:
    print(f"update={'false' if complete and not requested else 'true'}", file=f)
    print(f"version={version}", file=f)
    print(f"tag={tag}", file=f)
    print(f"amd64_url={assets[expected['amd64']]}", file=f)
    print(f"arm64_url={assets[expected['arm64']]}", file=f)
PY
