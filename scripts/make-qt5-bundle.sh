#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: make-qt5-bundle.sh --nimf-version VERSION --upstream-commit SHA \
  --arch amd64|arm64 --plugins-dir DIR --output FILE [--skip-elf-check]
EOF
}

nimf_version=
upstream_commit=
arch=
plugins_dir=
output=
skip_elf_check=0
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
while (($#)); do
	case $1 in
		--nimf-version) nimf_version=$2; shift 2 ;;
		--upstream-commit) upstream_commit=$2; shift 2 ;;
		--arch) arch=$2; shift 2 ;;
		--plugins-dir) plugins_dir=$2; shift 2 ;;
		--output) output=$2; shift 2 ;;
		--skip-elf-check) skip_elf_check=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) usage >&2; exit 2 ;;
	esac
done

[[ -n ${nimf_version} && ${upstream_commit} =~ ^[0-9a-f]{40}$ && -d ${plugins_dir} && -n ${output} ]] || {
	usage >&2
	exit 2
}
[[ ${arch} == amd64 || ${arch} == arm64 ]] || { echo "unsupported architecture: ${arch}" >&2; exit 2; }

if [[ ${arch} == amd64 ]]; then
	minors=(5.11 5.12 5.13 5.14 5.15)
else
	minors=(5.15)
fi

stage=$(mktemp -d)
trap 'rm -rf "${stage}"' EXIT
mkdir -p "${stage}/qt5"

for minor in "${minors[@]}"; do
	source_plugin="${plugins_dir}/${minor}/libqt5im-nimf.so"
	[[ -f ${source_plugin} ]] || { echo "missing Qt ${minor} plugin: ${source_plugin}" >&2; exit 1; }
	if (( ! skip_elf_check )); then
		machine=$(readelf -h "${source_plugin}" | sed -n 's/^[[:space:]]*Machine:[[:space:]]*//p')
		case ${arch}:${machine} in
			amd64:*X86-64*|arm64:*AArch64*) ;;
			*) echo "${source_plugin}: unexpected ELF machine ${machine}" >&2; exit 1 ;;
		esac
		readelf -d "${source_plugin}" | grep 'Shared library: \[libQt5Core.so.5\]' >/dev/null || {
			echo "${source_plugin}: Qt5Core dependency is missing" >&2; exit 1;
		}
		readelf -d "${source_plugin}" | grep 'Library soname: \[libqt5im-nimf.so\]' >/dev/null || {
			echo "${source_plugin}: unexpected or missing SONAME" >&2; exit 1;
		}
		embedded_minor=$("${script_dir}/qt-plugin-minor.sh" "${source_plugin}")
		[[ ${embedded_minor} == "${minor}" ]] || {
			echo "${source_plugin}: embedded Qt minor does not match ${minor}" >&2; exit 1;
		}
		if readelf -d "${source_plugin}" | grep -Eq '\((RPATH|RUNPATH)\)'; then
			echo "${source_plugin}: RPATH/RUNPATH is forbidden" >&2; exit 1
		fi
	fi
	destination="${stage}/qt5/${minor}/platforminputcontexts"
	mkdir -p "${destination}"
	install -m 0644 "${source_plugin}" "${destination}/libqt5im-nimf.so"
done

python3 - "${stage}" "${nimf_version}" "${upstream_commit}" "${arch}" <<'PY'
import hashlib
import json
import pathlib
import sys

stage = pathlib.Path(sys.argv[1])
full = {"5.11": "5.11.3", "5.12": "5.12.12", "5.13": "5.13.2", "5.14": "5.14.2", "5.15": "5.15.8"}
plugins = []
for path in sorted(stage.glob("qt5/*/platforminputcontexts/libqt5im-nimf.so")):
    minor = path.parts[-3]
    plugins.append({
        "qt_minor": minor,
        "qt_version": full[minor],
        "path": path.relative_to(stage).as_posix(),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    })
metadata = {
    "format": 1,
    "nimf_version": sys.argv[2],
    "upstream_commit": sys.argv[3],
    "architecture": sys.argv[4],
    "plugins": plugins,
}
(stage / "metadata.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
PY

(
	cd "${stage}"
	find qt5 -type f -print0 | sort -z | xargs -0 sha256sum >manifest.sha256
	sha256sum metadata.json >>manifest.sha256
)

mkdir -p "$(dirname -- "${output}")"
tar --sort=name --mtime="@${SOURCE_DATE_EPOCH:-0}" --owner=0 --group=0 --numeric-owner \
	-C "${stage}" -cJf "${output}" metadata.json manifest.sha256 qt5
