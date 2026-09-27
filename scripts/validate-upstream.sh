#!/usr/bin/env bash
set -euo pipefail

source_dir=${1:?Usage: validate-upstream.sh SOURCE_DIR VERSION TAG}
version=${2:?}
tag=${3:?}

configured=$(sed -n 's/^AC_INIT(nimf, \([^)]*\)).*/\1/p' "${source_dir}/configure.ac")
[[ ${configured} == "${version}" ]] || { echo "configure.ac says ${configured}, release says ${version}" >&2; exit 1; }
case ${tag} in
	"${version}"|"v${version}") ;;
	*) echo "tag ${tag} does not match ${version}" >&2; exit 1 ;;
esac

test -f "${source_dir}/modules/clients/qt5/im-nimf-qt5.cpp"
test -f "${source_dir}/modules/clients/qt5/nimf.json"
test -f "${source_dir}/modules/clients/qt5/org.nimf.clients.qt5.gschema.xml"
