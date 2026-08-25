# Image

## Load, decode, encode, and save

`Image.load` and `Image.decode` detect the encoded format from its bytes.
`Image.save(image, path)` selects a format from the file extension. Encoding
without a path uses format-specific options to make the requested output
explicit:

```sx
use Image
use Image.PNG

var image = Image.load("input.png")
let bytes = Image.encode(image, PNG.Options())
Image.save(image, "output.png")
```

The corresponding `try_load`, `try_decode`, `try_encode`, and `try_save`
operations return structured `Image.Error` values. `Image.ReadOptions` bounds
encoded bytes and decoded pixels before untrusted input can consume unlimited
resources.

PNG is the first implemented codec. `Image.JPEG` and `Image.WebP` are planned
as child modules whose option types will select future `Image.encode` and
`Image.save` overloads without exposing a codec registry.

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

The PNG adapter currently consumes GFX's portable SDL3 provider as private
infrastructure. SDL names and handles do not cross the public Image API.
