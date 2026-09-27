#!/usr/bin/env bash
set -euo pipefail

deb=${1:?Usage: extract-bookworm-plugin.sh DEB ARCH VERSION OUTPUT}
expected_arch=${2:?}
expected_version=${3:?}
output=${4:?}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

package_arch=$(dpkg-deb -f "${deb}" Architecture)
package_version=$(dpkg-deb -f "${deb}" Version)
package_depends=$(dpkg-deb -f "${deb}" Depends)
[[ ${package_arch} == "${expected_arch}" ]] || { echo "expected ${expected_arch}, got ${package_arch}" >&2; exit 1; }
[[ ${package_version} == "${expected_version}"* ]] || { echo "expected Nimf ${expected_version}, got ${package_version}" >&2; exit 1; }
[[ ${package_depends} == *qtbase-abi-5-15-8* ]] || { echo "package is not built for Qt 5.15.8" >&2; exit 1; }

stage=$(mktemp -d)
trap 'rm -rf "${stage}"' EXIT
dpkg-deb -x "${deb}" "${stage}"

case ${expected_arch} in
	amd64) triplet=x86_64-linux-gnu ;;
	arm64) triplet=aarch64-linux-gnu ;;
	*) echo "unsupported Debian architecture: ${expected_arch}" >&2; exit 2 ;;
esac

plugin="${stage}/usr/lib/${triplet}/qt5/plugins/platforminputcontexts/libqt5im-nimf.so"
schema="${stage}/usr/share/glib-2.0/schemas/org.nimf.clients.qt5.gschema.xml"
[[ -f ${plugin} && -f ${schema} ]] || { echo "Bookworm package lacks the Qt 5 plugin or schema" >&2; exit 1; }
readelf -d "${plugin}" | grep 'Library soname: \[libqt5im-nimf.so\]' >/dev/null || {
	echo "Bookworm plugin has an unexpected SONAME" >&2
	exit 1
}
[[ $("${script_dir}/qt-plugin-minor.sh" "${plugin}") == 5.15 ]] || {
	echo "Bookworm plugin does not embed the Qt 5.15 version tag" >&2
	exit 1
}
mkdir -p "$(dirname -- "${output}")"
install -m 0644 "${plugin}" "${output}"
