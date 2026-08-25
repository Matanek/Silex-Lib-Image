# Image

## Load, decode, encode, and save

`Image.load` and `Image.decode` detect the encoded format from its bytes.
`Image.save(image, path)` selects a format from the file extension. Encoding
without a path uses format-specific options to make the requested output
explicit:

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

The corresponding `try_load`, `try_decode`, `try_encode`, and `try_save`
operations return structured `Image.Error` values. `Image.ReadOptions` bounds
encoded bytes and decoded pixels before untrusted input can consume unlimited
resources.

PNG, JPEG, and WebP are built-in child modules. `Image.decode` and `Image.load`
detect all three from their byte signatures. `Image.save(image, path)` selects
PNG for `.png`, JPEG for `.jpg` or `.jpeg`, and WebP for `.webp`. Passing
format options explicitly selects the encoder regardless of the path suffix.

PNG is lossless and preserves RGBA8 pixels. Its initial `PNG.Options` is an
explicit format token reserved for future compression choices.

JPEG is lossy and cannot represent alpha. `JPEG.Options` exposes quality from
1 to 100, progressive output, YUV 4:4:4, 4:2:2, or 4:2:0 subsampling, and the
background color used to composite transparent pixels before encoding:

```sx
Image.save(image, "photo.jpg", JPEG.Options(
    quality:92,
    progressive:true,
    subsampling:JPEG.Subsampling.yuv420,
    background:Image.Color.white()
))
```

WebP supports lossy output through `quality` from 0 to 100 and exact lossless
RGBA8 output through `lossless:true`. In lossless mode, `quality` controls the
compression effort instead of introducing image loss:

```sx
Image.save(image, "preview.webp", WebP.Options(quality:78))
Image.save(image, "sprite.webp", WebP.Options(lossless:true))
```

The first codec set deliberately stays focused on the three common raster
formats. BMP, TIFF, and layered document formats such as PSD remain future
extensions rather than partial initial implementations.

## Edit with cascades

`Image` has shared class identity, so a mutable binding uses `var` and an
ordinary assignment shares subsequent edits. Edits mutate one owned `Image`
and return through the Silex cascade receiver:

```sx
var result = Image.load("input.png")
    ..crop(1200, 1200, Image.CropOptions(anchor:Image.Anchor.center))
    ..resize(512, 512, Image.ResizeOptions(
        mode:Image.ResizeMode.cover,
        filter:Image.Resampling.bilinear
    ))
    ..rotate(5.0)
    ..grayscale()
    ..contrast(1.10)
```

Use `copy` when the source must survive the edit:

```sx
var alternate = copy original
    ..flip_horizontal()
    ..brightness(0.08)
```

The initial geometric vocabulary is:

- `crop(region)` for exact coordinates;
- `crop(width, height, options)` for anchored crops and optional padding;
- `resize(width, height, options)` with `stretch`, `contain`, and `cover`;
- `rotate`, `rotate_left`, `rotate_right`, and `rotate_180`;
- `flip`, `flip_horizontal`, and `flip_vertical`.

The initial effects are `grayscale`, `invert`, `brightness`, `contrast`,
`blur`, and `sharpen`. Color adjustments preserve alpha; resampling and blur
interpolate premultiplied color so translucent edges do not acquire dark halos.

## Pixel contract

`Image` currently owns one contiguous RGBA8 pixel value. `pixel` and
`set_pixel` provide checked coordinates; `pixels()` exports the RGBA8 bytes.
All dimensions are positive and bounded to 100 million pixels.

The PNG adapter consumes GFX's portable SDL3 provider. JPEG and WebP use a
small package-owned native boundary over libjpeg-turbo and libwebp. Native
names, allocations, and handles remain private and never cross the public
Image API. Upstream versions, checksums, rebuild instructions, and licenses are
recorded under `Native/` and `Licenses/`.
