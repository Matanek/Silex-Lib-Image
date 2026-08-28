# Manipuler des images raster avec Image

Le package `Image` charge, enregistre et modifie des images raster avec une API
Silex orientée intentions. La première version prend en charge les images
RGBA8, les formats PNG, JPEG et WebP, ainsi que le recadrage, redimensionnement,
rotation, miroir, niveaux de gris, luminosité, contraste, flou et netteté.

[Read this documentation in English.](../EN/README.md)

## Installer le package

```text
silex install Image
```

Image demande Silex 0.41.0 ou une version plus récente.

## Charger, encoder et enregistrer

`Image.load` et `Image.decode` détectent le format à partir des octets.
`Image.save(image, path)` choisit le format selon l’extension. Sans chemin, des
options spécifiques rendent l’encodeur demandé explicite :

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

Ce fragment suppose un fichier `input.png` à côté de la source. Les opérations
`try_load`, `try_decode`, `try_encode` et `try_save` retournent des
`Image.Error` structurées. `Image.ReadOptions` borne les octets encodés et les
pixels décodés avant qu’une entrée non fiable consomme des ressources sans
limite.

PNG conserve les pixels RGBA8 sans perte. JPEG ne représente pas l’alpha ;
`JPEG.Options` expose la qualité de 1 à 100, le mode progressif, les
sous-échantillonnages YUV 4:4:4, 4:2:2 ou 4:2:0 et la couleur utilisée pour
composer les pixels transparents. WebP fournit un mode avec perte et un mode
RGBA8 exactement sans perte.

BMP, TIFF et les formats de documents en couches comme PSD restent de futures
extensions plutôt que des implémentations initiales partielles.

## Composer les modifications

`Image` est une classe mutable. Une affectation partage son identité ; `copy`
crée une image explicitement détachée. Les opérations modifient leur receveur
afin que plusieurs étapes se composent avec l’opérateur cascade :

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

`copy source` préserve l’original. Une cascade commencée directement par
`Image.load(...)` modifie au contraire la nouvelle image possédée.

Les opérations géométriques comprennent les deux formes de `crop`, `resize`
avec les modes `stretch`, `contain` et `cover`, les rotations et les miroirs.
Les effets comprennent `grayscale`, `invert`, `brightness`, `contrast`, `blur`
et `sharpen`. Les ajustements de couleur préservent l’alpha; le
rééchantillonnage et le flou interpolent des couleurs prémultipliées pour éviter
les halos sombres sur les bords translucides.

## Comprendre les pixels et la frontière native

Une `Image` possède une valeur de pixels RGBA8 contiguë. `pixel` et `set_pixel`
vérifient les coordonnées ; `pixels()` exporte les octets RGBA8. Les dimensions
sont positives et limitées à 100 millions de pixels.

L’adaptateur PNG consomme le provider SDL3 portable de GFX. JPEG et WebP
emploient une petite frontière native propre au package au-dessus de
libjpeg-turbo et libwebp. Les noms, allocations et handles natifs restent
privés et ne traversent jamais l’API `Image`.

Le manifeste fournit des archives pour macOS ARM64, Linux x64, Windows x64 et
Windows ARM64. Les trois premières cibles correspondent à la matrice distribuée
de Silex ; Windows ARM64 reste une cible reconnue et expérimentale, pas une
plateforme dont l’exécution est déclarée vérifiée. Les versions amont,
checksums, instructions de reconstruction et licences vivent sous `Native/` et
`Licenses/`.
