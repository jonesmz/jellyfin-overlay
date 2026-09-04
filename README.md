# jellyfin-overlay

A Gentoo overlay that builds **Jellyfin from source** (unlike the
`www-apps/jellyfin-bin` package in `::gentoo`, which repackages upstream's
prebuilt binaries).

The .NET server is compiled from source with the .NET SDK via the
`dotnet-pkg` eclass. The web client (`jellyfin-web`) is a separate
npm/webpack project that upstream does not publish as a standalone
artifact, so the prebuilt web bundle is extracted from the official
release tarball and installed as-is.
