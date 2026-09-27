#!/usr/bin/env bash
set -euo pipefail

source_dir=${1:?Usage: build-qt5-plugin.sh NIMF_SOURCE OUTPUT_DIR}
output_dir=${2:?}
qmake_bin=${QMAKE:-qmake}

[[ -f ${source_dir}/modules/clients/qt5/im-nimf-qt5.cpp ]] || { echo "invalid Nimf source tree" >&2; exit 2; }
command -v "${qmake_bin}" >/dev/null || { echo "qmake not found: ${qmake_bin}" >&2; exit 2; }
actual_qt_version=$("${qmake_bin}" -query QT_VERSION)
if [[ -n ${QT_VERSION:-} && ${actual_qt_version} != "${QT_VERSION}" ]]; then
	echo "SDK advertises Qt ${QT_VERSION}, qmake reports ${actual_qt_version}" >&2
	exit 1
fi

build_dir=$(mktemp -d)
trap 'rm -rf "${build_dir}"' EXIT
cat >"${build_dir}/nimf-qt5.pro" <<EOF
TEMPLATE = lib
CONFIG += plugin release c++11 link_pkgconfig
CONFIG -= debug
QT += core gui widgets core-private gui-private
TARGET = qt5im-nimf
DESTDIR = ${build_dir}/out
SOURCES = ${source_dir}/modules/clients/qt5/im-nimf-qt5.cpp
INCLUDEPATH += ${source_dir}/libnimf
PKGCONFIG += glib-2.0 gio-2.0 gobject-2.0
DEFINES += NIMF_COMPILATION USE_DLFCN QT_NO_KEYWORDS
LIBS += -ldl
QMAKE_LFLAGS += -Wl,--as-needed -Wl,-z,defs
EOF

"${qmake_bin}" "${build_dir}/nimf-qt5.pro" -o "${build_dir}/Makefile"
make -C "${build_dir}" -j"${JOBS:-$(nproc)}"

plugin="${build_dir}/out/libqt5im-nimf.so"
[[ -f ${plugin} ]] || { echo "qmake did not produce ${plugin}" >&2; exit 1; }
mkdir -p "${output_dir}"
install -m 0644 "${plugin}" "${output_dir}/libqt5im-nimf.so"

"$(dirname -- "${BASH_SOURCE[0]}")/test-qt5-plugin.sh" "${output_dir}/libqt5im-nimf.so" "${qmake_bin}"
