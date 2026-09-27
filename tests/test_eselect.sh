#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
module="$repo_root/app-i18n/nimf/files/nimf-qt5.eselect"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
describe() { :; }
die() { printf '%s\n' "$*" >&2; return 1; }
write_list_start() { :; }
write_kv_list_entry() { :; }
write_kv_list_start() { :; }
write_kv_list_end() { :; }

export ROOT="$tmpdir/"
mkdir -p "$ROOT/usr/lib64/nimf/qt5/5.11/platforminputcontexts"
mkdir -p "$ROOT/usr/lib64/nimf/qt5/5.15/platforminputcontexts"
touch "$ROOT/usr/lib64/nimf/qt5/5.11/platforminputcontexts/libqt5im-nimf.so"
touch "$ROOT/usr/lib64/nimf/qt5/5.15/platforminputcontexts/libqt5im-nimf.so"

# shellcheck source=/dev/null
source "$module"

[[ "$(get_versions)" == $'5.11\n5.15' ]] || fail "version discovery"
do_set 5.11
link="$ROOT/usr/lib64/qt5/plugins/platforminputcontexts/libqt5im-nimf.so"
[[ -L "$link" ]] || fail "selector did not create link"
[[ "$(readlink "$link")" == "/usr/lib64/nimf/qt5/5.11/platforminputcontexts/libqt5im-nimf.so" ]] || fail "unexpected link target"
[[ "$(get_selected_version)" == "5.11" ]] || fail "selected version"
do_set 5.15
[[ "$(get_selected_version)" == "5.15" ]] || fail "selection replacement"
if do_set 5.14 2>/dev/null; then
    fail "missing version was accepted"
fi

if command -v eselect >/dev/null; then
    home="$tmpdir/home"
    mkdir -p "$home/.eselect/modules"
    cp "$module" "$home/.eselect/modules/nimf-qt5.eselect"
    list_output=$(HOME="$home" eselect --root="$ROOT" nimf-qt5 list)
    [[ ${list_output} == *5.11* ]] || fail "eselect list action"
    HOME="$home" eselect --root="$ROOT" nimf-qt5 set 5.11 >/dev/null
    show_output=$(HOME="$home" eselect --root="$ROOT" nimf-qt5 show)
    [[ ${show_output} == *5.11* ]] || fail "eselect show action"
fi
