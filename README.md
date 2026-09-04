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

## Installing

The 12.0 releases are currently release candidates, keyworded `~amd64`:

```sh
echo '=media-tv/jellyfin-12.0_rc7 ~amd64' >> /etc/portage/package.accept_keywords
emerge -av media-tv/jellyfin
```

## Notes

- The `NUGETS` list in the ebuild is the full NuGet closure for the server,
  pinned per release. Regenerate it on every version bump with `gdmt restore`
  from `dev-dotnet/gentoo-dotnet-maintainer-tools`, run in a clean tagged
  checkout:

  ```sh
  gdmt restore --sdk-ver 10.0 --cache "$(pwd)/.cache" \
      --project Jellyfin.Server/Jellyfin.Server.csproj
  ```

- Some NuGet packages bundle prebuilt native libraries (PDFium, SkiaSharp,
  HarfBuzz). These are accepted as-is, matching the convention used by
  other `dotnet-pkg` ebuilds in `::gentoo`.
