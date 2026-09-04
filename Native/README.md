# Native codec boundary

Image owns a small C adapter over these upstream codec libraries:

- libjpeg-turbo 3.2.0, source SHA-256
  `6f30092cef9fb839779646608f4ee14ae3cbac989c47fa05e841b0841f09878e`;
- libwebp 1.6.0, source SHA-256
  `e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564`.

The source archives are the official
`libjpeg-turbo-3.2.0.tar.gz` GitHub release asset and
`libwebp-1.6.0.tar.gz` from `downloads.webmproject.org`. After verifying those
checksums and extracting both archives, rebuild every package archive with:

```text
Native/build-codecs.sh /path/to/libjpeg-turbo-3.2.0 /path/to/libwebp-1.6.0
Native/build-codecs.sh /path/to/libjpeg-turbo-3.2.0 /path/to/libwebp-1.6.0 macos-x64
Native/build-codecs.sh /path/to/libjpeg-turbo-3.2.0 /path/to/libwebp-1.6.0 linux-arm64
```

With no third argument the script reproduces the four established archives;
the explicit target forms build either additional desktop archive set. The
build fixes archive timestamps and remaps build paths. It disables
libjpeg-turbo SIMD and command-line tools. WebP uses its
portable static libraries, without threads or command-line tools; SIMD remains
enabled on x64 and Windows ARM64, while the macOS ARM64 build uses the portable
path. The Silex boundary exposes only Image-owned result handles and never
publishes either upstream C API.

The missing macOS X64 and Linux ARM64 archive sets were reproduced byte for
byte by GitHub Actions run `33907810659`. `Boundary/SHA256SUMS.txt` records all
six target sets and every target directory carries its machine-readable
artifact manifest.

Licenses and required notices are preserved under `Licenses/`.
