# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

ECM_TEST="forceoptional"
KFMIN=5.74.0
QTMIN=5.15.1
inherit ecm

if [[ ${PV} = *9999* ]]; then
	if [[ ${PV} != 9999 ]]; then
		EGIT_BRANCH="Plasma/$(ver_cut 1-2)"
	fi
	EGIT_REPO_URI="https://gitlab.com/kwinft/${PN}.git"
	inherit git-r3
else
	MY_PV=0.${PV/./}
	SRC_URI="https://gitlab.com/kwinft/${PN}/-/archive/${PN}@${MY_PV}/${PN}-${PN}@${MY_PV}.tar.gz"
	S="${WORKDIR}/${PN}-${PN}@${MY_PV}"
	KEYWORDS="~amd64"
fi

DESCRIPTION="Qt/C++ library wrapping libwayland"
HOMEPAGE="https://gitlab.com/kwinft/wrapland"

LICENSE="LGPL-2.1+"
SLOT="5"
IUSE=""

RDEPEND="
	>=dev-libs/wayland-1.15.0
	>=dev-qt/qtconcurrent-${QTMIN}:5
	>=dev-qt/qtgui-${QTMIN}:5[egl]
	media-libs/mesa[egl]
"
DEPEND="${RDEPEND}
	>=dev-libs/wayland-protocols-1.15
"

# All failing, I guess we need a virtual wayland server
RESTRICT+=" test"
