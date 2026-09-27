#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
version=${1:?Usage: render-ebuild.sh VERSION}
[[ ${version} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "invalid version: ${version}" >&2; exit 2; }

destination="${repo_root}/app-i18n/nimf/nimf-${version}.ebuild"
install -m 0644 "${repo_root}/templates/nimf.ebuild.in" "${destination}"
printf '%s\n' "${destination}"
