# Transform raster images with Image

The `Image` package loads, saves, and edits raster images through one
intention-oriented Silex API. The first version supports RGBA8 images, PNG,
JPEG, and WebP, plus cropping, resizing, rotation, mirroring, grayscale,
brightness, contrast, blur, and sharpening.

[Lire cette documentation en français.](../FR/README.md)

## Install the package

```text
silex install Image
```

This development revision requires the toolchain with `try` capture for
`Result` operations and extraction on ordinary calls.

## Load, encode, and save

`Image.load` and `Image.decode` detect the format from its bytes.
`Image.save(image, path)` chooses a format from the extension. Without a path,
format-specific options make the requested encoder explicit:

```sx
use Image
use Image.JPEG
use Image.PNG
use Image.WebP

var image = Image.load("input.png")
let png = Image.encode(image, PNG.Options())
let jpeg = Image.encode(image, JPEG.Options(quality:90))
let webp = Image.encode(image, WebP.Options(lossless:true))
Image.save(image, "output.png")
```

This fragment assumes an `input.png` file next to the source. The `load`,
`decode`, `encode`, and `save` operations each have one `Result` declaration.
An ordinary call returns the value or stops the program on failure;
`try Image.load(path)` keeps the result and its structured `Image.Error`. `Image.ReadOptions` bounds encoded bytes and
decoded pixels before untrusted input can consume unlimited resources.

PNG preserves RGBA8 pixels losslessly. JPEG cannot represent alpha;
`JPEG.Options` exposes quality from 1 to 100, progressive output, YUV 4:4:4,
4:2:2, or 4:2:0 subsampling, and the color used to composite transparent
pixels. WebP provides lossy output and exact lossless RGBA8 output.

BMP, TIFF, and layered formats such as PSD remain future extensions rather than
partial initial implementations.

## Compose edits

`Image` is a mutable class. Assignment shares its identity; `copy` creates an
explicit detached image. Operations mutate their receiver so several edits
compose through the cascade operator:

```sx
use Image
use Image.JPEG
use Image.PNG
use Image.WebP

var source = Image.load("portrait.png")
var thumbnail = copy source
    ..crop(800, 800)
    ..resize(256, 256)
    ..grayscale()
    ..contrast(1.15)
    ..sharpen(0.4)

Image.save(thumbnail, "avatar.png", PNG.Options())
Image.save(thumbnail, "avatar.jpg", JPEG.Options(quality:90))
Image.save(thumbnail, "avatar.webp", WebP.Options(lossless:true))
```

`copy source` preserves the original. A cascade that starts directly from
`Image.load(...)` instead edits the newly owned image.

Geometric operations include both `crop` forms, `resize` with `stretch`,
`contain`, and `cover`, rotations, and mirroring. Effects include `grayscale`,
`invert`, `brightness`, `contrast`, `blur`, and `sharpen`. Color adjustments
preserve alpha; resampling and blur interpolate premultiplied color to avoid
dark halos on translucent edges.

## Understand pixels and the native boundary

An `Image` owns one contiguous RGBA8 pixel value. `pixel` and `set_pixel` check
coordinates; `pixels()` exports RGBA8 bytes. Dimensions are positive and
bounded to 100 million pixels.

The PNG adapter consumes GFX's portable SDL3 provider. JPEG and WebP use a
small package-owned native boundary over libjpeg-turbo and libwebp. Native
names, allocations, and handles remain private and never cross the public
`Image` API.

The manifest provides archives for macOS ARM64, Linux x64, Windows x64, and
Windows ARM64. The first three match Silex's distributed matrix; Windows ARM64
remains a recognized experimental target, not a platform whose execution is
claimed as verified. Upstream versions, checksums, rebuild instructions, and
licenses live under `Native/` and `Licenses/`.
