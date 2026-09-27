#!/usr/bin/env bash
set -euo pipefail

plugin=${1:?Usage: test-qt5-plugin.sh PLUGIN [QMAKE]}
qmake_bin=${2:-${QMAKE:-qmake}}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f ${plugin} ]] || { echo "missing plugin: ${plugin}" >&2; exit 2; }

readelf -h "${plugin}" >/dev/null
readelf -d "${plugin}" | grep 'Shared library: \[libQt5Core.so.5\]' >/dev/null
readelf -d "${plugin}" | grep 'Library soname: \[libqt5im-nimf.so\]' >/dev/null
qt_minor=$("${qmake_bin}" -query QT_VERSION | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
[[ $("${script_dir}/qt-plugin-minor.sh" "${plugin}") == "${qt_minor}" ]]
if readelf -d "${plugin}" | grep -Eq '\((RPATH|RUNPATH)\)'; then
	echo "${plugin}: RPATH/RUNPATH is forbidden" >&2
	exit 1
fi

build_dir=$(mktemp -d)
trap 'rm -rf "${build_dir}"' EXIT
cat >"${build_dir}/verify.cpp" <<'CPP'
#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonObject>
#include <QPluginLoader>
#include <QStringList>

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    if (argc != 2) return 2;
    QPluginLoader loader(QString::fromLocal8Bit(argv[1]));
    const QJsonObject metadata = loader.metaData().value("MetaData").toObject();
    const QJsonArray keys = metadata.value("Keys").toArray();
    for (const QJsonValue &key : keys)
        if (key.toString() == QStringLiteral("nimf"))
            return loader.load() ? 0 : 3;
    return 4;
}
CPP
cat >"${build_dir}/verify.pro" <<EOF
TEMPLATE = app
CONFIG += console release
QT += core
SOURCES = ${build_dir}/verify.cpp
TARGET = verify-nimf-plugin
EOF
"${qmake_bin}" "${build_dir}/verify.pro" -o "${build_dir}/Makefile"
make -C "${build_dir}" -j"${JOBS:-$(nproc)}"
QT_QPA_PLATFORM=offscreen "${build_dir}/verify-nimf-plugin" "$(realpath "${plugin}")"
