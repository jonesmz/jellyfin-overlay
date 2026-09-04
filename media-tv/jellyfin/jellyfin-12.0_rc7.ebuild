# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Jellyfin server is a .NET application built from source with the .NET SDK.
# The web client (jellyfin-web) is a separate npm/webpack project; upstream
# does not publish it as a standalone artifact, so we lift the prebuilt web
# bundle out of the official server release tarball and install it as-is.
DOTNET_PKG_COMPAT="10.0"

# Full NuGet closure needed to restore the server project (Jellyfin.Server),
# which transitively covers the whole non-test project graph. Regenerate on
# every version bump with the official gdmt tool from
# dev-dotnet/gentoo-dotnet-maintainer-tools, run in a clean tagged checkout:
#   gdmt restore --sdk-ver 10.0 --cache "$(pwd)/.cache" \
#       --project Jellyfin.Server/Jellyfin.Server.csproj
#
# IMPORTANT: gdmt's default output is INCOMPLETE for this package. It filters
# out the .NET runtime packs on the assumption they are SDK-provided, but the
# eclass restores with --runtime linux-x64 (RID-specific), which genuinely
# needs them as packages. So after running gdmt, add the two linux-x64 runtime
# packs by hand (verified missing otherwise -> NU1101 at restore):
#   microsoft.aspnetcore.app.runtime.linux-x64@<ver>
#   microsoft.netcore.app.runtime.linux-x64@<ver>
# (gdmt --no-filter includes them, but also adds runtime packs for every other
# Linux RID (arm/arm64/musl), which we do not want.)
NUGETS="
	asynckeyedlock@8.0.2
	bblanchon.pdfium.linux@147.0.7690
	bblanchon.pdfium.macos@147.0.7690
	bblanchon.pdfium.win32@147.0.7690
	bdinfo@0.8.0
	bitfaster.caching@2.6.0
	blurhashsharp.skiasharp@1.4.0-pre.1
	blurhashsharp@1.4.0-pre.1
	commandlineparser@2.9.1
	diacritics@4.1.8
	discutils.core@0.16.13
	discutils.iso9660@0.16.13
	discutils.streams@0.16.13
	discutils.udf@0.16.13
	dotnet.glob@3.1.3
	excss@4.3.1
	harfbuzzsharp.nativeassets.linux@8.3.1.5
	harfbuzzsharp.nativeassets.macos@8.3.1.5
	harfbuzzsharp.nativeassets.win32@8.3.1.5
	harfbuzzsharp@8.3.1.5
	humanizer.core@2.14.1
	icu4n.transliterator@60.1.0-alpha.356
	icu4n@60.1.0-alpha.356
	idisposableanalyzers@4.0.8
	ignore@0.2.1
	j2n@2.0.0
	jellyfin.xmltv@10.12.0-pre1
	libse@4.0.12
	lrcparser@2025.623.0
	metabrainz.common.json@7.2.0
	metabrainz.common@4.1.1
	metabrainz.musicbrainz@8.0.1
	microsoft.aspnetcore.app.runtime.linux-x64@10.0.7
	microsoft.aspnetcore.authorization@10.0.11
	microsoft.aspnetcore.metadata@10.0.11
	microsoft.build.framework@17.11.31
	microsoft.build.framework@18.0.2
	microsoft.codeanalysis.analyzers@3.11.0
	microsoft.codeanalysis.analyzers@5.9.0
	microsoft.codeanalysis.bannedapianalyzers@5.6.0
	microsoft.codeanalysis.common@5.0.0
	microsoft.codeanalysis.common@5.9.0
	microsoft.codeanalysis.csharp.workspaces@5.0.0
	microsoft.codeanalysis.csharp@5.0.0
	microsoft.codeanalysis.csharp@5.9.0
	microsoft.codeanalysis.workspaces.common@5.0.0
	microsoft.codeanalysis.workspaces.msbuild@5.0.0
	microsoft.data.sqlite.core@10.0.11
	microsoft.data.sqlite@10.0.11
	microsoft.entityframeworkcore.abstractions@10.0.11
	microsoft.entityframeworkcore.analyzers@10.0.11
	microsoft.entityframeworkcore.design@10.0.11
	microsoft.entityframeworkcore.relational@10.0.11
	microsoft.entityframeworkcore.sqlite.core@10.0.11
	microsoft.entityframeworkcore.sqlite@10.0.11
	microsoft.entityframeworkcore.tools@10.0.11
	microsoft.entityframeworkcore@10.0.11
	microsoft.extensions.apidescription.server@10.0.0
	microsoft.extensions.caching.abstractions@10.0.11
	microsoft.extensions.caching.abstractions@2.0.0
	microsoft.extensions.caching.memory@10.0.11
	microsoft.extensions.caching.memory@2.0.0
	microsoft.extensions.configuration.abstractions@10.0.11
	microsoft.extensions.configuration.binder@10.0.11
	microsoft.extensions.configuration@10.0.11
	microsoft.extensions.dependencyinjection.abstractions@10.0.11
	microsoft.extensions.dependencyinjection.abstractions@2.0.0
	microsoft.extensions.dependencyinjection@10.0.11
	microsoft.extensions.dependencyinjection@9.0.0
	microsoft.extensions.dependencymodel@10.0.0
	microsoft.extensions.dependencymodel@10.0.11
	microsoft.extensions.diagnostics.abstractions@10.0.11
	microsoft.extensions.diagnostics.healthchecks.entityframeworkcore@10.0.11
	microsoft.extensions.diagnostics@10.0.11
	microsoft.extensions.fileproviders.abstractions@10.0.11
	microsoft.extensions.hosting.abstractions@10.0.11
	microsoft.extensions.http@10.0.11
	microsoft.extensions.logging.abstractions@10.0.11
	microsoft.extensions.logging.abstractions@9.0.0
	microsoft.extensions.logging@10.0.11
	microsoft.extensions.logging@9.0.0
	microsoft.extensions.options.configurationextensions@10.0.11
	microsoft.extensions.options@10.0.11
	microsoft.extensions.options@2.0.0
	microsoft.extensions.options@9.0.0
	microsoft.extensions.primitives@10.0.11
	microsoft.extensions.primitives@2.0.0
	microsoft.extensions.primitives@9.0.0
	microsoft.netcore.app.runtime.linux-x64@10.0.7
	microsoft.netcore.platforms@1.1.0
	microsoft.openapi@2.7.5
	microsoft.visualstudio.solutionpersistence@1.0.52
	microsoft.win32.systemevents@9.0.2
	mimetypes@2.5.2
	mono.texttemplating@3.0.0
	morestachio@5.0.1.670
	nebml@1.1.0.5
	netstandard.library@2.0.3
	newtonsoft.json@13.0.3
	newtonsoft.json@13.0.4
	pdftoimage@5.2.1
	playlistsnet@1.4.1
	polly.core@8.7.0
	polly@8.7.0
	prometheus-net.aspnetcore@8.2.1
	prometheus-net.dotnetruntime@4.4.1
	prometheus-net@3.1.2
	prometheus-net@8.2.1
	serilog.aspnetcore@10.0.0
	serilog.enrichers.thread@4.0.0
	serilog.expressions@5.0.0
	serilog.extensions.hosting@10.0.0
	serilog.extensions.logging@10.0.0
	serilog.formatting.compact@3.0.0
	serilog.settings.configuration@10.0.1
	serilog.sinks.async@2.1.0
	serilog.sinks.console@6.1.1
	serilog.sinks.debug@3.0.0
	serilog.sinks.file@7.0.0
	serilog.sinks.graylog@3.1.1
	serilog@4.0.0
	serilog@4.1.0
	serilog@4.2.0
	serilog@4.3.0
	seriloganalyzer@0.15.0
	sharpcompress@0.50.4
	shimskiasharp@3.7.0
	skiasharp.harfbuzz@3.119.4
	skiasharp.nativeassets.linux.nodependencies@3.119.2
	skiasharp.nativeassets.linux@3.119.4
	skiasharp.nativeassets.macos@3.119.2
	skiasharp.nativeassets.macos@3.119.4
	skiasharp.nativeassets.win32@3.119.2
	skiasharp.nativeassets.win32@3.119.4
	skiasharp@2.88.9
	skiasharp@3.116.1
	skiasharp@3.119.2
	skiasharp@3.119.4
	smartanalyzers.multithreadinganalyzer@1.1.31
	sqlitepclraw.bundle_e_sqlite3@2.1.12
	sqlitepclraw.core@2.1.12
	sqlitepclraw.lib.e_sqlite3@2.1.12
	sqlitepclraw.provider.e_sqlite3@2.1.12
	stylecop.analyzers.unstable@1.2.0.556
	stylecop.analyzers@1.2.0-beta.556
	svg.custom@3.7.0
	svg.model@3.7.0
	svg.skia@3.7.0
	swashbuckle.aspnetcore.redoc@10.2.3
	swashbuckle.aspnetcore.swagger@10.2.3
	swashbuckle.aspnetcore.swaggergen@10.2.3
	swashbuckle.aspnetcore.swaggerui@10.2.3
	swashbuckle.aspnetcore@10.2.3
	system.buffers@4.6.1
	system.codedom@6.0.0
	system.collections.immutable@10.0.1
	system.composition.attributedmodel@9.0.0
	system.composition.convention@9.0.0
	system.composition.hosting@9.0.0
	system.composition.runtime@9.0.0
	system.composition.typedparts@9.0.0
	system.composition@9.0.0
	system.drawing.common@9.0.2
	system.memory@4.5.5
	system.memory@4.6.3
	system.numerics.vectors@4.6.1
	system.reflection.metadata@10.0.1
	system.runtime.compilerservices.unsafe@6.0.0
	system.runtime.compilerservices.unsafe@6.1.2
	system.text.encoding.codepages@8.0.0
	system.threading.tasks.extensions@4.6.3
	taglibsharp@2.3.0
	tmdblib@3.0.0
	ude.netstandard@1.2.0
	utf.unknown@2.5.1
	utf.unknown@2.7.0
	z440.atl.core@7.16.0
	zlib.net-mutliplatform@1.0.8
"

inherit dotnet-pkg systemd tmpfiles

# Upstream tags releases like "v12.0-rc7"; Portage version is "12.0_rc7".
MY_PV="${PV/_rc/-rc}"

DESCRIPTION="Free Software Media System (server built from source)"
HOMEPAGE="https://jellyfin.org/
	https://github.com/jellyfin/jellyfin/"

SRC_URI="
	https://github.com/jellyfin/jellyfin/archive/v${MY_PV}.tar.gz
		-> ${P}.gh.tar.gz
	https://repo.jellyfin.org/files/server/linux/preview/v${MY_PV}/amd64/jellyfin_${MY_PV}-amd64.tar.xz
		-> jellyfin-web-${PV}.tar.xz
	${NUGET_URIS}
"
S="${WORKDIR}/jellyfin-${MY_PV}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

# Runtime libraries the server links/execs at runtime. The .NET build is
# framework-dependent and pulls its managed deps from the vendored nugets, so
# none of these are needed at compile time (no DEPEND entry for them).
RDEPEND="
	acct-group/jellyfin
	acct-user/jellyfin
	dev-libs/icu
	media-libs/fontconfig
	media-video/ffmpeg[vpx,x264]
	virtual/zlib:=
"
# The .NET SDK build dependency (virtual/dotnet-sdk:${DOTNET_PKG_COMPAT}) is
# added to BDEPEND automatically by dotnet-pkg.eclass. We only need the
# jellyfin user/group at install time for the fowners calls in src_install.
BDEPEND="
	acct-group/jellyfin
	acct-user/jellyfin
"

# Explicit allowlist of what we build: just the server entry point. Its
# transitive project references cover the entire non-test project graph, so
# restoring/building this one project pulls exactly the server NuGet closure
# (verified: a project-only restore yields the same 178 packages as a
# test-stripped full-solution restore).
#
# NOTE: we intentionally do NOT let the eclass restore the whole Jellyfin.sln.
# The default dotnet-pkg_src_configure also runs a solution-wide restore, which
# would drag in the tests/ projects and their test-only NuGets (xunit, Moq,
# AutoFixture, ...). Our src_configure override below restores only the
# projects listed here, so new test projects added upstream can never sneak
# back into our dependency set.
DOTNET_PKG_PROJECTS=( "${S}/Jellyfin.Server/Jellyfin.Server.csproj" )

INST_DIR="/usr/share/${PN}"

src_unpack() {
	# The default dotnet-pkg_src_unpack would "unpack" every non-nupkg archive
	# in ${A}, including the whole upstream server -bin tarball. We only want
	# its jellyfin-web/ subtree, so compose the unpack manually: link the
	# nugets into NUGET_PACKAGES and unpack just the source tarball.
	nuget_link-system-nugets
	nuget_link-nuget-archives
	unpack "${P}.gh.tar.gz"

	# Extract only the prebuilt web client from the upstream release tarball.
	# It lives at jellyfin/jellyfin-web/ inside the archive.
	mkdir -p "${WORKDIR}/jellyfin-web-bundle" || die
	tar -xJf "${DISTDIR}/jellyfin-web-${PV}.tar.xz" \
		-C "${WORKDIR}/jellyfin-web-bundle" \
		--strip-components=2 jellyfin/jellyfin-web || die "web extract failed"
}

src_configure() {
	dotnet-pkg-base_info

	# Restore only the projects in DOTNET_PKG_PROJECTS. Deliberately skip the
	# eclass default's solution-wide restore (dotnet-pkg-base_foreach-solution)
	# so the tests/ projects are never restored. See DOTNET_PKG_PROJECTS above.
	dotnet-pkg_foreach-project \
		dotnet-pkg-base_restore "${DOTNET_PKG_RESTORE_EXTRA_ARGS[@]}"
}

src_install() {
	# Install the compiled server output into ${INST_DIR}.
	dotnet-pkg-base_install "${INST_DIR}"

	# Install the prebuilt web client alongside the server output so the
	# default web path (<basedir>/jellyfin-web) resolves; the service files
	# also pass --webdir explicitly.
	insinto "${INST_DIR}/jellyfin-web"
	doins -r "${WORKDIR}/jellyfin-web-bundle/."

	# Launcher wrapper: /usr/bin/jellyfin -> the framework-dependent server.
	dotnet-pkg-base_dolauncher "${INST_DIR}/jellyfin"

	# State directories.
	keepdir /var/log/jellyfin
	fowners jellyfin:jellyfin /var/log/jellyfin
	keepdir /etc/jellyfin
	fowners jellyfin:jellyfin /etc/jellyfin
	newtmpfiles - jellyfin.conf <<<"d /var/cache/jellyfin 0775 jellyfin jellyfin -"

	# Service integration.
	newinitd "${FILESDIR}/jellyfin.init-r1" "${PN}"
	newconfd "${FILESDIR}/jellyfin.confd" "${PN}"
	systemd_dounit "${FILESDIR}/jellyfin.service"

	einstalldocs
}

pkg_postinst() {
	tmpfiles_process jellyfin.conf

	elog "This is a release-candidate build of Jellyfin ${PV}."
	elog "The web client was installed from the upstream prebuilt release,"
	elog "not built from source."
	elog
	elog "Jellyfin makes backward-incompatible database changes between minor"
	elog "releases. The first startup after an upgrade runs a database"
	elog "migration that must not be interrupted. Once started, downgrading"
	elog "requires restoring the database from a backup."
}
