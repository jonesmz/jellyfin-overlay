# jellyfin-overlay

A Gentoo overlay that builds **Jellyfin from source** (unlike the
`www-apps/jellyfin-bin` package in `::gentoo`, which repackages upstream's
prebuilt binaries).

The .NET server is compiled from source with the .NET SDK via the
`dotnet-pkg` eclass. The web client (`jellyfin-web`) is a separate
npm/webpack project that upstream does not publish as a standalone
artifact, so the prebuilt web bundle is extracted from the official
release tarball and installed as-is.

## Contents

- `media-tv/jellyfin` — Jellyfin server, built from source.

## Requirements

- `dev-dotnet/dotnet-sdk-bin:10.0` (or a source `dev-dotnet/dotnet-sdk:10.0`),
  pulled in automatically via `virtual/dotnet-sdk`.
- `media-video/ffmpeg[vpx,x264]`.

## Enabling the overlay

Add it to your Portage configuration (as root):

```sh
cat > /etc/portage/repos.conf/jellyfin-overlay.conf <<'EOF'
[jellyfin-overlay]
location = /var/db/repos/jellyfin-overlay
sync-type = git
sync-uri = git@github.com:jonesmz/jellyfin-overlay.git
masters = gentoo
auto-sync = yes
EOF
emaint sync -r jellyfin-overlay
```

## Installing

The 12.0 releases are currently release candidates, keyworded `~amd64`.
To install one, accept the keyword:

```sh
echo '=media-tv/jellyfin-12.0_rc7 ~amd64' >> /etc/portage/package.accept_keywords
emerge -av media-tv/jellyfin
```

## Notes

- The `NUGETS` list in the ebuild is the full transitive NuGet closure for
  the server, pinned per release. It is regenerated on every version bump
  by running `dotnet restore --use-lock-file` against the release tag and
  aggregating the resolved packages from the produced `packages.lock.json`
  files.
- Some NuGet packages bundle prebuilt native libraries (PDFium, SkiaSharp,
  HarfBuzz). These are accepted as-is, matching the convention used by
  other `dotnet-pkg` ebuilds in `::gentoo`.
