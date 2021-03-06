# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit eutils git-r3 qmake-utils xdg

DESCRIPTION="Music player for the large local collections"
HOMEPAGE="https://olegantonyan.github.io/mpz/"
EGIT_REPO_URI="https://github.com/olegantonyan/${PN}.git"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

RDEPEND="
	dev-qt/qtcore:5
	dev-qt/qtmultimedia:5
	dev-qt/qtx11extras:5
"

DEPEND="${RDEPEND}"

src_configure() {
	# Generate binary translations.
	lrelease ${PN}.pro || die

	# noccache is required to call the correct compiler.
	eqmake5
}

src_install() {
	default
	emake install INSTALL_ROOT="${D}"
}
