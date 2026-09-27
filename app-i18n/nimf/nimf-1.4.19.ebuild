# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools gnome2-utils xdg

DESCRIPTION="Lightweight, extensible input method framework with versioned Qt 5 plugins"
HOMEPAGE="https://github.com/hamonikr/nimf https://github.com/june3474/nimf-overlay"

NIMF_SOURCE="nimf-${PV}.tar.gz"
QT5_AMD64_BUNDLE="nimf-qt5-plugins-${PV}-amd64.tar.xz"
QT5_ARM64_BUNDLE="nimf-qt5-plugins-${PV}-arm64.tar.xz"

SRC_URI="
	https://github.com/hamonikr/nimf/archive/refs/tags/v${PV}.tar.gz -> ${NIMF_SOURCE}
	qt5? (
		amd64? ( https://github.com/june3474/nimf-overlay/releases/download/nimf-${PV}/${QT5_AMD64_BUNDLE} )
		arm64? ( https://github.com/june3474/nimf-overlay/releases/download/nimf-${PV}/${QT5_ARM64_BUNDLE} )
	)
"
S="${WORKDIR}/nimf-${PV}"

LICENSE="LGPL-3+ MIT HPND"
SLOT="0/1"
KEYWORDS="~amd64 ~arm64"
IUSE="+X +gtk2 +gtk4 +hangul +qt5 anthy m17n rime"

REQUIRED_USE="qt5? ( || ( amd64 arm64 ) )"

RDEPEND="
	dev-libs/glib:2
	dev-libs/wayland
	dev-util/glib-utils
	dev-qt/qtbase:6=[gui,widgets]
	x11-libs/gtk+:3
	x11-libs/libxkbcommon
	X? (
		dev-libs/libayatana-appindicator
		x11-libs/libX11
		x11-libs/libxklavier
	)
	gtk2? ( x11-libs/gtk+:2 )
	gtk4? ( gui-libs/gtk:4 )
	qt5? ( app-admin/eselect )
	hangul? ( app-i18n/libhangul )
	anthy? ( app-i18n/anthy )
	m17n? (
		dev-db/m17n-db
		dev-libs/m17n-lib
	)
	rime? ( app-i18n/librime )
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-libs/wayland-protocols
	dev-util/wayland-scanner
	dev-util/gtk-doc
	dev-util/intltool
	gnome-base/librsvg:2
	sys-devel/gettext
	virtual/pkgconfig
"

PATCHES=( "${FILESDIR}/nimf-gentoo.patch" )

QA_PREBUILT="usr/lib*/nimf/qt5/*/platforminputcontexts/libqt5im-nimf.so"

src_unpack() {
	unpack "${NIMF_SOURCE}"

	if use qt5; then
		mkdir "${WORKDIR}/qt5-bundle" || die
		if use amd64; then
			tar -xJf "${DISTDIR}/${QT5_AMD64_BUNDLE}" -C "${WORKDIR}/qt5-bundle" || die
		elif use arm64; then
			tar -xJf "${DISTDIR}/${QT5_ARM64_BUNDLE}" -C "${WORKDIR}/qt5-bundle" || die
		fi
	fi
}

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	local myeconfargs=(
		--disable-qt5
		--enable-qt6
		--without-im-config-data
		--without-imsettings-data
		--with-gtk=3
		$(use_enable X x11)
		$(use_enable gtk2)
		$(use_enable gtk4)
		$(use_enable hangul nimf-libhangul)
		$(use_enable anthy nimf-anthy)
		$(use_enable m17n nimf-m17n)
		$(use_enable rime nimf-rime)
	)
	econf "${myeconfargs[@]}"
}

src_install() {
	default
	find "${ED}" -name '*.la' -delete || die

	if use qt5; then
		insinto "/usr/$(get_libdir)/nimf"
		doins -r "${WORKDIR}/qt5-bundle/qt5"

		insinto /usr/share/glib-2.0/schemas
		doins modules/clients/qt5/org.nimf.clients.qt5.gschema.xml

		insinto /usr/share/eselect/modules
		doins "${FILESDIR}/nimf-qt5.eselect"

		dostrip -x "/usr/$(get_libdir)/nimf/qt5"
	fi
}

pkg_preinst() {
	gnome2_schemas_savelist
}

nimf_update_gtk4_cache() {
	local module_dir="${EROOT}/usr/$(get_libdir)/gtk-4.0/4.0.0/immodules"
	local updater="${EROOT}/usr/bin/gio-querymodules"
	[[ -d ${module_dir} && -x ${updater} ]] || return 0
	"${updater}" "${module_dir}" || ewarn "Failed to update the GTK 4 input module cache"
}

pkg_postinst() {
	use gtk2 && gnome2_query_immodules_gtk2
	gnome2_query_immodules_gtk3
	use gtk4 && nimf_update_gtk4_cache
	gnome2_schemas_update
	xdg_icon_cache_update

	if use qt5 && [[ ${ROOT} == / ]] && \
		[[ ! -e ${EROOT}/usr/$(get_libdir)/qt5/plugins/platforminputcontexts/libqt5im-nimf.so ]]; then
		eselect nimf-qt5 set 5.15
	fi

	einfo "Set GTK_IM_MODULE=nimf, QT_IM_MODULE=nimf and XMODIFIERS=@im=nimf in your session."
}

pkg_postrm() {
	gnome2_query_immodules_gtk2
	gnome2_query_immodules_gtk3
	nimf_update_gtk4_cache
	gnome2_schemas_update
	xdg_icon_cache_update

	if ! has_version "${CATEGORY}/${PN}"; then
		local selector="${EROOT}/usr/$(get_libdir)/qt5/plugins/platforminputcontexts/libqt5im-nimf.so"
		if [[ -L ${selector} && $(readlink "${selector}") == /usr/$(get_libdir)/nimf/qt5/* ]]; then
			rm -f "${selector}" || die
		fi
	fi
}
