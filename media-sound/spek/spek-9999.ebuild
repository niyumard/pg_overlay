# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7
WX_GTK_VER="3.1-gtk3"

inherit autotools eutils git-r3 toolchain-funcs wxwidgets

DESCRIPTION="Analyse your audio files by showing their spectrogram"
HOMEPAGE="http://www.spek-project.org/"
EGIT_REPO_URI="https://github.com/alexkay/${PN}.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	media-video/ffmpeg:0=
	x11-libs/wxGTK:${WX_GTK_VER}[X]
"
DEPEND="${RDEPEND}
	dev-util/intltool
	virtual/pkgconfig
	>=sys-devel/gcc-4.7
	sys-devel/gettext
"
src_prepare() {
    default
	need-wxwidgets unicode
	eapply \
		"${FILESDIR}"/${PN}-disable-updates.patch \
		"${FILESDIR}"/${PN}-replace-gnu+11-with-c++11.patch \
		"${FILESDIR}"/${PN}-stdlib.patch
	eautoreconf
}
