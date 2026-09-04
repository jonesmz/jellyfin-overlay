#!/usr/bin/env python3
"""Generate the NPM_DEPS block for an npm.eclass ebuild from a lockfile.

Reads a package-lock.json (lockfileVersion 2/3) and emits one
"<url> <distfile-name>" line per unique resolved dependency tarball, in the
tab-indented form ready to paste into the ebuild's NPM_DEPS variable.

The distfile name is collision-free:
  * registry deps -> "<scope-without-@>+<name>+<basename>"
  * other URL deps -> "npmurl-<host-and-path, sanitized>"

Usage:
  gen-npm-deps.py path/to/package-lock.json > npm-deps.txt
"""
import json
import re
import sys


def distfile_name(url):
    prefix = "https://registry.npmjs.org/"
    if url.startswith(prefix):
        pkgid = url[len(prefix):].split("/-/")[0]  # name or @scope/name
        base = url.split("/-/")[-1]                # foo-1.2.3.tgz
        return f"{pkgid.replace('@', '').replace('/', '+')}+{base}"
    safe = re.sub(r"[^A-Za-z0-9._-]+", "-", url.split("://", 1)[-1])
    if not safe.endswith((".tgz", ".tar.gz")):
        safe += ".tar.gz"
    return f"npmurl-{safe}"


def main(lockfile):
    lock = json.load(open(lockfile))
    seen = {}
    for meta in lock.get("packages", {}).values():
        url = meta.get("resolved")
        if not (url and url.startswith("http")):
            continue
        if url in seen:
            continue
        seen[url] = distfile_name(url)
    names = list(seen.values())
    if len(names) != len(set(names)):
        sys.exit("error: distfile name collision; naming scheme needs fixing")
    for url, name in sorted(seen.items()):
        print(f"\t{url} {name}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
