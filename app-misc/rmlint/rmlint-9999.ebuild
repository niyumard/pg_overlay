# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PLOCALES="de es fr"
PYTHON_COMPAT=( python3_{7..9} )

inherit git-r3 gnome2-utils l10n python-r1 scons-utils

DESCRIPTION="rmlint finds space waste and other broken things on your filesystem and offers to remove it"
HOMEPAGE="https://github.com/sahib/rmlint"
EGIT_REPO_URI="https://github.com/sahib/${PN}.git"
EGIT_BRANCH="develop"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""
IUSE="X doc"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="X? ( x11-libs/gtksourceview:3.0
		doc? ( dev-python/sphinx[${PYTHON_USEDEP}] )
		dev-libs/json-glib
		dev-python/pygobject:3[${PYTHON_USEDEP}]
		gnome-base/librsvg:2
		x11-libs/gtk+:3 )"
DEPEND="${RDEPEND}
	dev-util/scons[${PYTHON_USEDEP}]
	sys-devel/gettext
	virtual/pkgconfig"

src_prepare(){
	default
	l10n_find_plocales_changes po "" .po
	rm_locale() {
		rm -fv po/"${1}".po || die "removing of ${1}.po failed"
	}
	l10n_for_each_disabled_locale_do rm_locale
}

src_configure(){
	escons config LIBDIR=/usr/$(get_libdir) --prefix="${ED}"/usr --actual-prefix=/usr
}

src_compile(){
	escons DEBUG=0 CC="$(tc-getCC)" LIBDIR=/usr/$(get_libdir) --prefix="${ED}"/usr --actual-prefix=/usr
}

src_install(){
	escons install DEBUG=0 LIBDIR=/usr/$(get_libdir) --prefix="${ED}"/usr --actual-prefix=/usr 
	rm -f ${ED}/usr/share/glib-2.0/schemas/gschemas.compiled
	if ! use X; then
		rm -rf "${D}"/usr/share/{glib-2.0,icons,applications}
		rm -rf "${D}"/usr/lib
	fi
	if ! use doc; then
		rm -rf "${D}"/usr/share/man
	fi
}

pkg_postinst() {
	use X && gnome2_schemas_update
	xdg_icon_cache_update
}

pkg_postrm() {
	use X && gnome2_schemas_update
	xdg_icon_cache_update
}
