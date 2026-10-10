#!/usr/bin/env bash
# Bump the jellyfin-overlay packages to a new upstream release.
#
# Regenerates everything that is version-specific:
#   * www-apps/jellyfin-server : the NUGETS dependency closure (via a
#       project-only, RID-specific `dotnet restore`), spliced into a new ebuild
#   * media-video/jellyfin-web : the NPM_DEPS closure (via gen-npm-deps.py),
#       spliced into a new ebuild
#   * www-apps/jellyfin        : the metapackage, copied to the new version
#   * Manifests for the server and web packages
#
# The rest of each ebuild is version-agnostic (keys off ${PV}/${MY_PV}), so
# only the dependency block and the filename change.
#
# Usage:
#   scripts/bump.sh <upstream-tag>        e.g. scripts/bump.sh v12.2
#   scripts/bump.sh <upstream-tag> --keep-old   (do not git-rm the old versions)
#
# Requirements (host tools):
#   * dev-dotnet/dotnet-sdk-bin:10.0 (or a source dotnet-sdk:10.0) — provides
#     `dotnet`; found via PATH, then eselect, then /opt/dotnet-sdk-bin-*
#   * net-libs/nodejs[npm]           — only needed to sanity-check; the npm dep
#     list is derived from package-lock.json, no npm run required
#   * app-portage/pkgdev             — `pkgdev manifest`
#   * git, curl, python3
set -euo pipefail

TAG="${1:?usage: bump.sh <upstream-tag> [--keep-old]}"
KEEP_OLD=0
[[ "${2:-}" == "--keep-old" ]] && KEEP_OLD=1

# Portage version from the tag: strip leading 'v', map upstream '-rc' -> '_rc'.
PV="${TAG#v}"
PV="${PV/-rc/_rc}"

OVERLAY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

msg() { printf '\n>>> %s\n' "$*" ; }

find_dotnet() {
	if command -v dotnet >/dev/null 2>&1 ; then command -v dotnet ; return ; fi
	local d
	d="$(eselect dotnet show 2>/dev/null || true)"
	[[ -n ${d} && -x /opt/${d}/dotnet ]] && { echo "/opt/${d}/dotnet" ; return ; }
	for d in /opt/dotnet-sdk-bin-*/dotnet /usr/lib*/dotnet-sdk-*/dotnet ; do
		[[ -x ${d} ]] && { echo "${d}" ; return ; }
	done
	echo "ERROR: dotnet not found. Install dev-dotnet/dotnet-sdk-bin:10.0." >&2
	exit 1
}

# --- server: NUGETS -------------------------------------------------------
gen_nugets() {
	local dotnet; dotnet="$(find_dotnet)"
	msg "server: cloning jellyfin ${TAG}"
	git clone --depth 1 --branch "${TAG}" \
		https://github.com/jellyfin/jellyfin.git "${WORK}/server" >/dev/null 2>&1
	rm -f "${WORK}/server/global.json"
	msg "server: dotnet restore (project-only, --runtime linux-x64)"
	DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 \
		"${dotnet}" restore "${WORK}/server/Jellyfin.Server/Jellyfin.Server.csproj" \
		--runtime linux-x64 --packages "${WORK}/nugets" --verbosity quiet
	# Enumerate every <name>@<version> populated in the restore cache.
	# This RID restore includes the linux-x64 runtime packs that `gdmt`
	# filters out, so no manual addition is needed.
	python3 - "${WORK}/nugets" > "${WORK}/nugets.txt" <<'PY'
import os, sys
cache = sys.argv[1]
pkgs = set()
for name in os.listdir(cache):
	p = os.path.join(cache, name)
	if not os.path.isdir(p):
		continue
	for ver in os.listdir(p):
		if os.path.isdir(os.path.join(p, ver)) and not ver.startswith("."):
			pkgs.add(f"\t{name.lower()}@{ver}")
print("\n".join(sorted(pkgs)))
PY
	msg "server: $(grep -c . "${WORK}/nugets.txt") nugets"
}

# --- web: NPM_DEPS --------------------------------------------------------
gen_npm_deps() {
	msg "web: fetching jellyfin-web ${TAG} package-lock.json"
	curl -sfL "https://raw.githubusercontent.com/jellyfin/jellyfin-web/${TAG}/package-lock.json" \
		-o "${WORK}/package-lock.json"
	python3 "${OVERLAY}/scripts/gen-npm-deps.py" "${WORK}/package-lock.json" \
		> "${WORK}/npmdeps.txt"
	msg "web: $(grep -c . "${WORK}/npmdeps.txt") npm deps"
}

# Replace the inline dependency block (between VAR=" and the lone closing ")
# of an ebuild with the contents of a file. Writes to the new ebuild path.
splice_block() {
	local src="$1" dst="$2" var="$3" block="$4"
	python3 - "$src" "$dst" "$var" "$block" <<'PY'
import sys
src, dst, var, block = sys.argv[1:5]
lines = open(src, encoding="utf-8").read().splitlines(keepends=True)
out, i, n = [], 0, len(lines)
start = f'{var}="\n'
while i < n:
	out.append(lines[i])
	if lines[i] == start:
		# skip old block body until the lone closing '"'
		i += 1
		while i < n and lines[i].rstrip("\n") != '"':
			i += 1
		out.append(open(block, encoding="utf-8").read())
		out.append('"\n')
	i += 1
open(dst, "w", encoding="utf-8").write("".join(out))
PY
}

bump_one() {
	local dir="$1" pn="$2" var="$3" block="$4"
	local old new
	old="$(ls "${OVERLAY}/${dir}/${pn}"-*.ebuild | head -1)"
	new="${OVERLAY}/${dir}/${pn}-${PV}.ebuild"
	if [[ -n ${block} ]] ; then
		splice_block "${old}" "${new}" "${var}" "${block}"
	else
		cp "${old}" "${new}"
	fi
	msg "wrote ${new#${OVERLAY}/}"
	if [[ ${KEEP_OLD} -eq 0 && ${old} != "${new}" ]] ; then
		git -C "${OVERLAY}" rm -q "${old}"
	fi
}

gen_nugets
gen_npm_deps

bump_one www-apps/jellyfin-server jellyfin-server NUGETS   "${WORK}/nugets.txt"
bump_one media-video/jellyfin-web jellyfin-web     NPM_DEPS "${WORK}/npmdeps.txt"
bump_one www-apps/jellyfin        jellyfin         ""       ""

msg "regenerating Manifests (fetches the new distfiles)"
( cd "${OVERLAY}/www-apps/jellyfin-server" && pkgdev manifest )
( cd "${OVERLAY}/media-video/jellyfin-web" && pkgdev manifest )

msg "done. Review, pkgcheck, then commit:"
echo "    pkgcheck scan www-apps/jellyfin www-apps/jellyfin-server media-video/jellyfin-web"
