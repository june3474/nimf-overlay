#!/usr/bin/env bash
set -euo pipefail

plugin=${1:?Usage: qt-plugin-minor.sh PLUGIN}
[[ -f ${plugin} ]] || { echo "missing plugin: ${plugin}" >&2; exit 2; }

header=$(LC_ALL=C readelf -x .qtmetadata "${plugin}" 2>/dev/null \
	| awk '/0x[0-9a-f]+/ { print $2 $3 $4 $5; exit }')
magic=51544d45544144415441202100
[[ ${header} == "${magic}"?????? ]] || {
	echo "${plugin}: invalid or unsupported Qt plugin metadata" >&2
	exit 1
}

major_hex=${header:26:2}
minor_hex=${header:28:2}
printf '%d.%d\n' "0x${major_hex}" "0x${minor_hex}"
