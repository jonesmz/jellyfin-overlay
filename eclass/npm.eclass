# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: npm.eclass
# @MAINTAINER:
# jonesmz
# @SUPPORTED_EAPIS: 8
# @BLURB: Build npm/Node.js projects offline from individually-fetched deps
# @DESCRIPTION:
# This eclass builds Node.js projects (webpack/npm applications) entirely
# offline, without a hand-hosted node_modules tarball. Each npm dependency is
# fetched as an individual distfile (mirrored and hash-verified by Portage like
# any other SRC_URI entry). At build time the eclass rewrites the project's
# package-lock.json "resolved" fields to point at the local distfiles
# (file:// URLs), so "npm ci --offline" installs from disk with no network.
#
# The dependency set is declared in the "NPM_DEPS" variable as a list of
# "url<space>filename" pairs (one per line). Generate it from a project's
# package-lock.json with the accompanying scripts/gen-npm-deps.py helper.
# "NPM_DEPS" is expanded into SRC_URI automatically (as NPM_SRC_URI).
#
# @SUBSECTION Integrity / supply-chain
#
# Dependency integrity is enforced ENTIRELY by the Portage Manifest: each
# NPM_DEPS tarball is a normal distfile with a committed checksum, so a
# tampered download is rejected before the build. The npm-native SRI
# (package-lock.json "integrity") is NOT relied upon — the "resolved" fields
# are rewritten to local file:// paths, so npm reads the Manifest-verified
# files. This relocates integrity to Portage, it does not weaken it.
#
# By default the eclass runs "npm ci" with "--ignore-scripts", so NONE of the
# dependencies' install/prepare lifecycle scripts execute at build time. This
# eliminates the arbitrary-code-execution surface that a normal "npm ci" (which
# runs lifecycle scripts for every package) would introduce. A consumer whose
# build genuinely needs lifecycle scripts (e.g. native addons compiled via
# node-gyp) must opt in by setting NPM_CI_IGNORE_SCRIPTS="no"; do that only
# after auditing which scripts run.
#
# @EXAMPLE:
# @CODE
# NPM_DEPS="
#   https://registry.npmjs.org/ms/-/ms-2.0.0.tgz ms+ms-2.0.0.tgz
#   ...
# "
# inherit npm
# SRC_URI="https://example.com/${P}.tar.gz ${NPM_SRC_URI}"
# NPM_BUILD_SCRIPT="build:production"
#
# src_install() {
#     insinto /usr/share/${PN}
#     doins -r dist/.
# }
# @CODE

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_NPM_ECLASS} ]] ; then
_NPM_ECLASS=1

# @ECLASS_VARIABLE: NPM_NODE_MIN
# @PRE_INHERIT
# @DESCRIPTION:
# Minimum net-libs/nodejs version required to build (must satisfy the
# project's package.json "engines.node"). Set before inheriting to override.
: "${NPM_NODE_MIN:=20}"

BDEPEND+=" >=net-libs/nodejs-${NPM_NODE_MIN}[npm] "

# @ECLASS_VARIABLE: NPM_DEPS
# @DEFAULT_UNSET
# @PRE_INHERIT
# @DESCRIPTION:
# Whitespace-separated list of "<url> <distfile-name>" pairs, one dependency
# per line. Every npm dependency (the full package-lock.json closure) must be
# listed. Used to build NPM_SRC_URI and to map each package to its local
# tarball during the offline install.

# @ECLASS_VARIABLE: NPM_SRC_URI
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# SRC_URI fragment generated from NPM_DEPS. Append to the ebuild's SRC_URI.

# @ECLASS_VARIABLE: NPM_BUILD_SCRIPT
# @DESCRIPTION:
# The package.json script that produces the build output. Run by npm_run in
# the default src_compile. Defaults to "build".
: "${NPM_BUILD_SCRIPT:=build}"

# @ECLASS_VARIABLE: NPM_CI_IGNORE_SCRIPTS
# @DESCRIPTION:
# Whether "npm ci" is run with --ignore-scripts (i.e. no dependency lifecycle
# scripts execute). Defaults to "yes" (safe). Set to "no" only if the build
# genuinely needs lifecycle scripts, after auditing them.
: "${NPM_CI_IGNORE_SCRIPTS:=yes}"

# @ECLASS_VARIABLE: NPM_OFFLINE_CACHE
# @DESCRIPTION:
# Path to the npm cache used during the build. Defaults to a directory in the
# build tree so nothing touches the user's real npm cache.
: "${NPM_OFFLINE_CACHE:=${WORKDIR}/.npm-cache}"

# @ECLASS_VARIABLE: NPM_INSTALL_DIR
# @DESCRIPTION:
# Directory the default npm_src_install copies the build output into.
# Defaults to /usr/share/${PN}.
: "${NPM_INSTALL_DIR:=/usr/share/${PN}}"

# @ECLASS_VARIABLE: NPM_BUILD_OUTPUT
# @DESCRIPTION:
# Path (relative to ${S}) of the build output dir installed by the default
# npm_src_install. Defaults to "dist".
: "${NPM_BUILD_OUTPUT:=dist}"

# Build NPM_SRC_URI from NPM_DEPS: "url -> name" per Portage rename syntax.
# Runs at eclass source time (depend phase), so it must not use here-strings
# or here-documents: bash materializes those into a temp file in CWD, which is
# a read-only sandboxed directory during depend -> mkstemp denied. Split the
# NPM_DEPS string on whitespace with word-splitting instead.
_npm_set_src_uri() {
	local -a fields
	local i url name
	NPM_SRC_URI=""
	# Word-split NPM_DEPS into a flat array of alternating url/name tokens.
	# Disable globbing first so a token containing a glob metacharacter can't
	# be expanded against the CWD (word splitting is intentional).
	local reset_glob=0
	[[ $- == *f* ]] || { set -f ; reset_glob=1 ; }
	fields=( ${NPM_DEPS} )
	(( reset_glob )) && set +f
	for (( i = 0; i + 1 < ${#fields[@]}; i += 2 )) ; do
		url="${fields[i]}"
		name="${fields[i+1]}"
		NPM_SRC_URI+=" ${url} -> ${name}"
	done
}
_npm_set_src_uri

# @FUNCTION: npm_pkg_setup
# @DESCRIPTION:
# Sanity-check that node and npm are available.
npm_pkg_setup() {
	[[ ${MERGE_TYPE} == binary ]] && return
	type -P node >/dev/null || die "node not found"
	type -P npm >/dev/null || die "npm not found"
}

# @VARIABLE: _NPM_REWRITE_JS
# @INTERNAL
# @DESCRIPTION:
# The Node.js lockfile-rewrite program, stored as a plain string (no
# here-document, which would make bash create a temp file in CWD when the
# eclass is sourced — forbidden by the sandbox during the depend phase).
# Written to ${T} and executed at build time by npm_ci.
_NPM_REWRITE_JS='
const fs = require("fs");
const distdir = process.env.NPM_DISTDIR;
const map = {};
for (const line of fs.readFileSync(process.env.NPM_DEPS_FILE, "utf8").split("\n")) {
	const t = line.trim();
	if (!t) continue;
	const sp = t.indexOf(" ");
	const url = t.slice(0, sp), name = t.slice(sp + 1).trim();
	map[url] = "file://" + distdir + "/" + name;
}
const lock = JSON.parse(fs.readFileSync("package-lock.json", "utf8"));
if (!(lock.lockfileVersion >= 2) || !lock.packages) {
	console.error("npm.eclass: package-lock.json must be lockfileVersion >= 2 "
		+ "(has a packages{} map). Got: " + lock.lockfileVersion);
	process.exit(1);
}
const rewriteSpecs = (obj) => {
	for (const sect of ["dependencies", "devDependencies", "optionalDependencies"]) {
		if (!obj[sect]) continue;
		for (const [k, v] of Object.entries(obj[sect]))
			if (typeof v === "string" && map[v]) obj[sect][k] = "file:" + map[v].slice(7);
	}
};
for (const p of Object.values(lock.packages))
	if (p.resolved && map[p.resolved]) p.resolved = map[p.resolved];
if (lock.packages[""]) rewriteSpecs(lock.packages[""]);
fs.writeFileSync("package-lock.json", JSON.stringify(lock));
const pj = JSON.parse(fs.readFileSync("package.json", "utf8"));
rewriteSpecs(pj);
fs.writeFileSync("package.json", JSON.stringify(pj, null, 2));
'

# @FUNCTION: npm_ci
# @DESCRIPTION:
# Rewrite package-lock.json (and package.json for non-registry URL deps) so all
# dependency "resolved" URLs point at the local distfiles, then run
# "npm ci --offline". Must be run from the directory containing package.json.
npm_ci() {
	# NPM_DEPS can be thousands of lines; pass it (and the rewrite program) via
	# files in ${T}, never the environment or a here-document.
	local depsfile="${T}/npm-deps.txt"
	local jsfile="${T}/npm-rewrite.js"
	printf '%s\n' "${NPM_DEPS}" > "${depsfile}" || die
	printf '%s\n' "${_NPM_REWRITE_JS}" > "${jsfile}" || die

	# Rewrite resolved URLs (and non-registry URL specs) -> file:// distfiles.
	NPM_DISTDIR="${DISTDIR}" NPM_DEPS_FILE="${depsfile}" \
		node "${jsfile}" || die "npm.eclass: lockfile rewrite failed"

	local -x npm_config_cache="${NPM_OFFLINE_CACHE}"
	local -x npm_config_offline=true
	local -x npm_config_audit=false
	local -x npm_config_fund=false
	local -x npm_config_update_notifier=false

	local -a ci_args=( --offline --no-audit --no-fund )
	[[ ${NPM_CI_IGNORE_SCRIPTS} == yes ]] && ci_args+=( --ignore-scripts )

	npm ci "${ci_args[@]}" || die "npm ci --offline failed"
}

# @FUNCTION: npm_run
# @USAGE: <script> [args...]
# @DESCRIPTION:
# Run a package.json script via "npm run" with node_modules/.bin on PATH.
npm_run() {
	[[ -z ${1} ]] && die "npm_run: no script given"
	local -x PATH="${PWD}/node_modules/.bin:${PATH}"
	local -x npm_config_offline=true
	npm run "${@}" || die "npm run ${1} failed"
}

# @FUNCTION: npm_src_unpack
# @DESCRIPTION:
# Unpack only the non-dependency archives (the project source). The npm
# dependency tarballs listed in NPM_DEPS are consumed as tarballs directly
# from DISTDIR by npm_ci, so unpacking all ~thousands of them into WORKDIR is
# pure waste; they are skipped here.
npm_src_unpack() {
	# Collect the set of NPM_DEPS distfile names to skip.
	local -a fields
	local reset_glob=0
	[[ $- == *f* ]] || { set -f ; reset_glob=1 ; }
	fields=( ${NPM_DEPS} )
	(( reset_glob )) && set +f
	local i
	local -A npm_distfiles=()
	for (( i = 1; i < ${#fields[@]}; i += 2 )) ; do
		npm_distfiles["${fields[i]}"]=1
	done

	local archive
	for archive in ${A} ; do
		[[ -n ${npm_distfiles[${archive}]} ]] && continue
		unpack "${archive}"
	done
}

# @FUNCTION: npm_src_compile
# @DESCRIPTION:
# Default src_compile: offline install then run NPM_BUILD_SCRIPT.
npm_src_compile() {
	npm_ci
	npm_run "${NPM_BUILD_SCRIPT}"
}

# @FUNCTION: npm_src_install
# @DESCRIPTION:
# Default src_install: install the contents of NPM_BUILD_OUTPUT into
# NPM_INSTALL_DIR. Redefine in the ebuild for anything more elaborate.
npm_src_install() {
	insinto "${NPM_INSTALL_DIR}"
	doins -r "${NPM_BUILD_OUTPUT}"/.
	einstalldocs
}

fi

EXPORT_FUNCTIONS pkg_setup src_unpack src_compile src_install
