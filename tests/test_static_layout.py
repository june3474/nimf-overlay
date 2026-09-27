#!/usr/bin/env python3
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class OverlayLayoutTest(unittest.TestCase):
    def read(self, relative: str) -> str:
        path = ROOT / relative
        self.assertTrue(path.is_file(), f"missing {relative}")
        return path.read_text()

    def test_repository_metadata(self) -> None:
        self.assertEqual(self.read("profiles/repo_name").strip(), "nimf-overlay")
        layout = self.read("metadata/layout.conf")
        self.assertIn("masters = gentoo", layout)
        self.assertIn("thin-manifests = true", layout)

    def test_ebuild_policy(self) -> None:
        ebuild = self.read("app-i18n/nimf/nimf-1.4.19.ebuild")
        self.assertEqual(ebuild, self.read("templates/nimf.ebuild.in"))
        for fragment in (
            'EAPI=8',
            'SLOT="0/1"',
            'KEYWORDS="~amd64 ~arm64"',
            'IUSE="+X +gtk2 +gtk4 +hangul +qt5 anthy m17n rime"',
            '--disable-qt5',
            '--enable-qt6',
            'dev-qt/qtbase:6=',
            'QA_PREBUILT=',
            'dostrip -x',
            'gnome2_schemas_update',
            'gio-querymodules',
        ):
            self.assertIn(fragment, ebuild)
        self.assertIn('--with-gtk=3', ebuild)
        self.assertNotRegex(ebuild, r'usex gtk4 4 3')
        self.assertNotIn("QT_PLUGIN_PATH", ebuild)

        metadata = self.read("app-i18n/nimf/metadata.xml")
        self.assertIn("Build the GTK 4 input method module", metadata)
        self.assertNotIn("use GTK 4 for nimf-settings", metadata)

    def test_qt5_versions_are_declared_once(self) -> None:
        versions = self.read("config/qt5-sdks.tsv")
        workflow = self.read(".github/workflows/build-sdk-images.yml")
        rows = [line.split("\t") for line in versions.splitlines() if line and not line.startswith("#")]
        self.assertEqual([row[0] for row in rows], ["5.11", "5.12", "5.13", "5.14"])
        self.assertEqual([row[1] for row in rows], ["5.11.3", "5.12.12", "5.13.2", "5.14.2"])
        for row in rows:
            self.assertRegex(row[2], r"^[0-9a-f]{64}$")
            self.assertIn(f'version: "{row[1]}"', workflow)
            self.assertIn(f"sha256: {row[2]}", workflow)

    def test_qt_511_gcc9_compatibility_patch_is_pinned(self) -> None:
        dockerfile = self.read("containers/qt5-sdk/Dockerfile")
        patch = self.read("containers/qt5-sdk/patches/qt-5.11-gcc9.patch")
        workflow = self.read(".github/workflows/build-sdk-images.yml")
        self.assertIn("COPY containers/qt5-sdk/patches", dockerfile)
        self.assertIn('if [ "${QT_MINOR}" = 5.11 ]', dockerfile)
        self.assertIn("typedef quint32 result_type;", patch)
        self.assertIn("e094806951ff7337b5b0c534db479e3808f153a7", patch)
        self.assertIn("containers/qt5-sdk/patches/**", workflow)

    def test_qt5_plugin_has_portable_linker_metadata(self) -> None:
        build = self.read("scripts/build-qt5-plugin.sh")
        verify = self.read("scripts/test-qt5-plugin.sh")
        self.assertIn("CONFIG += no_qt_rpath", build)
        self.assertIn("-Wl,-soname,libqt5im-nimf.so", build)
        self.assertIn("NIMF_QT_BUILD_VERSION=", build)
        self.assertIn("QT_INSTALL_LIBS", verify)
        self.assertIn("loader.errorString()", verify)
        version_reader = self.read("scripts/qt-plugin-minor.sh")
        self.assertIn("NIMF_QT_BUILD_VERSION=", version_reader)

    def test_workflows_match_release_policy(self) -> None:
        update = self.read(".github/workflows/update-nimf.yml")
        self.assertIn('cron: "17 3 * * 1"', update)
        self.assertIn("workflow_dispatch:", update)
        self.assertIn("pull-requests: write", update)
        self.assertIn("contents: write", update)
        self.assertIn("persist-credentials: false", update)
        self.assertIn("matrix:", update)
        self.assertIn("5.11", update)
        self.assertIn("5.14", update)
        self.assertIn("arm64", update)
        self.assertIn("prerelease", update)
        self.assertIn("[DEFAULT]", update)
        self.assertIn("main-repo = gentoo", update)
        self.assertIn("[gentoo]", update)
        self.assertIn("location = /var/db/repos/gentoo", update)
        self.assertIn("emerge-webrsync -q", update)
        self.assertNotIn("emerge --sync gentoo", update)
        self.assertNotIn("emerge --sync --repo", update)
        self.assertIn("media-libs/freetype harfbuzz", update)
        self.assertIn("dev-libs/libdbusmenu gtk3", update)
        self.assertIn("app-i18n/libhangul ~arm64", update)
        finalize = self.read(".github/workflows/finalize-release.yml")
        self.assertIn("--prerelease=false", finalize)

    def test_patch_adds_qt5_disable_and_drops_gtk4_cache_hook(self) -> None:
        patch = self.read("app-i18n/nimf/files/nimf-gentoo.patch")
        self.assertIn("AC_ARG_ENABLE([qt5]", patch)
        self.assertIn("enable_qt5", patch)
        self.assertIn("modules/clients/gtk/Makefile.am", patch)
        self.assertIn("gtk4-query-immodules", patch)
        self.assertEqual(patch.count("with_im_config_data=$withval"), 1)
        self.assertEqual(patch.count("with_imsettings_data=$withval"), 1)

    def test_documented_no_global_qt_plugin_path(self) -> None:
        readme = self.read("README.md")
        self.assertIn("eselect nimf-qt5", readme)
        self.assertIn("QT_IM_MODULE=nimf", readme)
        self.assertIn("GTK_IM_MODULE=nimf", readme)
        self.assertIn('XMODIFIERS="@im=nimf"', readme)
        self.assertIn("한컴오피스", self.read("README.html"))
        self.assertNotIn("export QT_PLUGIN_PATH", readme)

    def test_install_and_uninstall_environment_messages(self) -> None:
        ebuild = self.read("app-i18n/nimf/nimf-1.4.19.ebuild")
        for message in (
            'elog "To use Nimf as your input method framework,"',
            'elog "set the following environment variables in ~/.xprofile or /etc/xprofile."',
            'elog "Alternatively, create a shell script under /etc/X11/xinit/xinitrc.d/."',
            'elog "export GTK_IM_MODULE=nimf"',
            "elog 'export QT4_IM_MODULE=\"nimf\"'",
            'elog "export QT_IM_MODULE=nimf"',
            'elog "export QT6_IM_MODULE=nimf"',
            "elog 'export XMODIFIERS=\"@im=nimf\"'",
            'elog "Nimf has been removed."',
            'elog "unset GTK_IM_MODULE QT4_IM_MODULE QT_IM_MODULE QT6_IM_MODULE XMODIFIERS"',
        ):
            self.assertIn(message, ebuild)
        self.assertNotIn('einfo "Set GTK_IM_MODULE=', ebuild)


if __name__ == "__main__":
    unittest.main(verbosity=2)
