# Image

Image loads, saves, and edits raster images through one intention-oriented
Silex API. The first release provides RGBA8 images, PNG input and output,
cropping, resizing, rotation, mirroring, grayscale conversion, brightness,
contrast, blur, and sharpening.

```text
silex install Image
```

`Image` is a mutable class. Assigning it shares the same image identity;
`copy image` creates an explicit detached image. Its operations mutate their
receiver deliberately so several edits compose
through the Silex cascade operator without creating an API-level copy between
every step:

```sx
use Image
use Image.PNG

var source = Image.load("portrait.png")
var thumbnail = copy source
    ..crop(800, 800)
    ..resize(256, 256)
    ..grayscale()
    ..contrast(1.15)
    ..sharpen(0.4)

Image.save(thumbnail, "avatar.png", PNG.Options())
```

`copy source` is the explicit Silex spelling when the original must remain
unchanged. A cascade starting from `Image.load(...)` edits the newly owned
temporary directly.

See [Docs/README.md](Docs/README.md) for the complete initial contract and
[Examples/Cascade.sx](Examples/Cascade.sx) for an executable pipeline.
