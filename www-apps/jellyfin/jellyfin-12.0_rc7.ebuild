# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Jellyfin puts you in control of managing and streaming your media"
HOMEPAGE="https://jellyfin.org/
	https://github.com/jellyfin/jellyfin/"

# Metapackage: the Jellyfin server plus its web UI.
LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	~www-apps/jellyfin-server-${PV}
	~media-video/jellyfin-web-${PV}
"
