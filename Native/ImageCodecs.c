#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "turbojpeg.h"
#include "webp/decode.h"
#include "webp/encode.h"

enum {
    IMAGE_CODEC_OK = 0,
    IMAGE_CODEC_INVALID_INPUT = 1,
    IMAGE_CODEC_TOO_LARGE = 2,
    IMAGE_CODEC_FAILURE = 3,
    IMAGE_CODEC_OUT_OF_MEMORY = 4
};

typedef struct ImageCodecResult {
    uint8_t *bytes;
    size_t byte_count;
    int32_t width;
    int32_t height;
    int32_t status;
} ImageCodecResult;

static const size_t IMAGE_CODEC_MAXIMUM_OUTPUT = 128u * 1024u * 1024u;

static ImageCodecResult *image_codec_result(int32_t status) {
    ImageCodecResult *result = (ImageCodecResult *)calloc(1, sizeof(ImageCodecResult));
    if (result != NULL) {
        result->status = status;
    }
    return result;
}

static int image_codec_dimensions(
    int32_t width,
    int32_t height,
    size_t maximum_pixels,
    size_t *pixel_count,
    size_t *byte_count
) {
    if (width <= 0 || height <= 0) {
        return IMAGE_CODEC_INVALID_INPUT;
    }
    const size_t w = (size_t)width;
    const size_t h = (size_t)height;
    if (w > maximum_pixels / h) {
        return IMAGE_CODEC_TOO_LARGE;
    }
    const size_t pixels = w * h;
    if (pixels > SIZE_MAX / 4u) {
        return IMAGE_CODEC_TOO_LARGE;
    }
    *pixel_count = pixels;
    *byte_count = pixels * 4u;
    return IMAGE_CODEC_OK;
}

static int image_codec_copy(
    ImageCodecResult *result,
    const uint8_t *bytes,
    size_t byte_count
) {
    if (byte_count == 0 || byte_count > IMAGE_CODEC_MAXIMUM_OUTPUT) {
        return IMAGE_CODEC_TOO_LARGE;
    }
    result->bytes = (uint8_t *)malloc(byte_count);
    if (result->bytes == NULL) {
        return IMAGE_CODEC_OUT_OF_MEMORY;
    }
    memcpy(result->bytes, bytes, byte_count);
    result->byte_count = byte_count;
    return IMAGE_CODEC_OK;
}

ImageCodecResult *silex_image_jpeg_decode(
    const uint8_t *encoded,
    size_t encoded_size,
    size_t maximum_pixels
) {
    ImageCodecResult *result = image_codec_result(IMAGE_CODEC_FAILURE);
    if (result == NULL) {
        return NULL;
    }
    if (encoded == NULL || encoded_size == 0 || maximum_pixels == 0) {
        result->status = IMAGE_CODEC_INVALID_INPUT;
        return result;
    }

    tjhandle decoder = tj3Init(TJINIT_DECOMPRESS);
    if (decoder == NULL) {
        result->status = IMAGE_CODEC_OUT_OF_MEMORY;
        return result;
    }
    if (tj3DecompressHeader(decoder, encoded, encoded_size) < 0) {
        tj3Destroy(decoder);
        return result;
    }

    const int32_t width = (int32_t)tj3Get(decoder, TJPARAM_JPEGWIDTH);
    const int32_t height = (int32_t)tj3Get(decoder, TJPARAM_JPEGHEIGHT);
    size_t pixel_count = 0;
    size_t byte_count = 0;
    result->status = image_codec_dimensions(
        width,
        height,
        maximum_pixels,
        &pixel_count,
        &byte_count
    );
    if (result->status != IMAGE_CODEC_OK) {
        tj3Destroy(decoder);
        return result;
    }

    result->bytes = (uint8_t *)malloc(byte_count);
    if (result->bytes == NULL) {
        result->status = IMAGE_CODEC_OUT_OF_MEMORY;
        tj3Destroy(decoder);
        return result;
    }
    if (tj3Decompress8(
        decoder,
        encoded,
        encoded_size,
        result->bytes,
        width * 4,
        TJPF_RGBA
    ) < 0) {
        free(result->bytes);
        result->bytes = NULL;
        tj3Destroy(decoder);
        return result;
    }

    tj3Destroy(decoder);
    result->byte_count = byte_count;
    result->width = width;
    result->height = height;
    result->status = IMAGE_CODEC_OK;
    return result;
}

ImageCodecResult *silex_image_jpeg_encode(
    const uint8_t *rgba,
    int32_t width,
    int32_t height,
    int32_t quality,
    int32_t progressive,
    int32_t subsampling,
    int32_t background_r,
    int32_t background_g,
    int32_t background_b
) {
    ImageCodecResult *result = image_codec_result(IMAGE_CODEC_FAILURE);
    if (result == NULL) {
        return NULL;
    }
    size_t pixel_count = 0;
    size_t byte_count = 0;
    result->status = image_codec_dimensions(
        width,
        height,
        SIZE_MAX / 4u,
        &pixel_count,
        &byte_count
    );
    if (result->status != IMAGE_CODEC_OK || rgba == NULL || quality < 1 || quality > 100) {
        result->status = IMAGE_CODEC_INVALID_INPUT;
        return result;
    }

    uint8_t *opaque = (uint8_t *)malloc(byte_count);
    if (opaque == NULL) {
        result->status = IMAGE_CODEC_OUT_OF_MEMORY;
        return result;
    }
    for (size_t index = 0; index < pixel_count; ++index) {
        const size_t offset = index * 4u;
        const unsigned alpha = rgba[offset + 3u];
        const unsigned inverse = 255u - alpha;
        opaque[offset] = (uint8_t)((rgba[offset] * alpha + (unsigned)background_r * inverse + 127u) / 255u);
        opaque[offset + 1u] = (uint8_t)((rgba[offset + 1u] * alpha + (unsigned)background_g * inverse + 127u) / 255u);
        opaque[offset + 2u] = (uint8_t)((rgba[offset + 2u] * alpha + (unsigned)background_b * inverse + 127u) / 255u);
        opaque[offset + 3u] = 255u;
    }

    tjhandle encoder = tj3Init(TJINIT_COMPRESS);
    if (encoder == NULL) {
        free(opaque);
        result->status = IMAGE_CODEC_OUT_OF_MEMORY;
        return result;
    }
    if (
        tj3Set(encoder, TJPARAM_QUALITY, quality) < 0 ||
        tj3Set(encoder, TJPARAM_SUBSAMP, subsampling) < 0 ||
        tj3Set(encoder, TJPARAM_PROGRESSIVE, progressive != 0) < 0
    ) {
        free(opaque);
        tj3Destroy(encoder);
        return result;
    }

    uint8_t *encoded = NULL;
    size_t encoded_size = 0;
    if (tj3Compress8(
        encoder,
        opaque,
        width,
        width * 4,
        height,
        TJPF_RGBA,
        &encoded,
        &encoded_size
    ) < 0) {
        free(opaque);
        tj3Destroy(encoder);
        return result;
    }
    free(opaque);
    tj3Destroy(encoder);

    result->status = image_codec_copy(result, encoded, encoded_size);
    tj3Free(encoded);
    return result;
}

ImageCodecResult *silex_image_webp_decode(
    const uint8_t *encoded,
    size_t encoded_size,
    size_t maximum_pixels
) {
    ImageCodecResult *result = image_codec_result(IMAGE_CODEC_FAILURE);
    if (result == NULL) {
        return NULL;
    }
    if (encoded == NULL || encoded_size == 0 || maximum_pixels == 0) {
        result->status = IMAGE_CODEC_INVALID_INPUT;
        return result;
    }

    int width = 0;
    int height = 0;
    if (!WebPGetInfo(encoded, encoded_size, &width, &height)) {
        return result;
    }
    size_t pixel_count = 0;
    size_t byte_count = 0;
    result->status = image_codec_dimensions(
        (int32_t)width,
        (int32_t)height,
        maximum_pixels,
        &pixel_count,
        &byte_count
    );
    if (result->status != IMAGE_CODEC_OK) {
        return result;
    }

    result->bytes = (uint8_t *)malloc(byte_count);
    if (result->bytes == NULL) {
        result->status = IMAGE_CODEC_OUT_OF_MEMORY;
        return result;
    }
    if (WebPDecodeRGBAInto(
        encoded,
        encoded_size,
        result->bytes,
        byte_count,
        width * 4
    ) == NULL) {
        free(result->bytes);
        result->bytes = NULL;
        return result;
    }

    result->byte_count = byte_count;
    result->width = (int32_t)width;
    result->height = (int32_t)height;
    result->status = IMAGE_CODEC_OK;
    return result;
}

ImageCodecResult *silex_image_webp_encode(
    const uint8_t *rgba,
    int32_t width,
    int32_t height,
    float quality,
    int32_t lossless
) {
    ImageCodecResult *result = image_codec_result(IMAGE_CODEC_FAILURE);
    if (result == NULL) {
        return NULL;
    }
    size_t pixel_count = 0;
    size_t byte_count = 0;
    result->status = image_codec_dimensions(
        width,
        height,
        SIZE_MAX / 4u,
        &pixel_count,
        &byte_count
    );
    if (
        result->status != IMAGE_CODEC_OK || rgba == NULL ||
        quality < 0.0f || quality > 100.0f
    ) {
        result->status = IMAGE_CODEC_INVALID_INPUT;
        return result;
    }

    if (lossless != 0) {
        WebPConfig config;
        WebPPicture picture;
        WebPMemoryWriter writer;
        if (!WebPConfigInit(&config) || !WebPPictureInit(&picture)) {
            return result;
        }

        config.lossless = 1;
        config.quality = quality;
        config.exact = 1;
        if (!WebPValidateConfig(&config)) {
            WebPPictureFree(&picture);
            return result;
        }

        picture.use_argb = 1;
        picture.width = width;
        picture.height = height;
        WebPMemoryWriterInit(&writer);
        picture.writer = WebPMemoryWrite;
        picture.custom_ptr = &writer;

        const int imported = WebPPictureImportRGBA(&picture, rgba, width * 4);
        const int encoded = imported && WebPEncode(&config, &picture);
        if (encoded && writer.mem != NULL && writer.size != 0) {
            result->status = image_codec_copy(result, writer.mem, writer.size);
        }
        WebPPictureFree(&picture);
        WebPMemoryWriterClear(&writer);
        return result;
    }

    uint8_t *encoded = NULL;
    const size_t encoded_size = WebPEncodeRGBA(
        rgba,
        width,
        height,
        width * 4,
        quality,
        &encoded
    );
    if (encoded_size == 0 || encoded == NULL) {
        return result;
    }
    result->status = image_codec_copy(result, encoded, encoded_size);
    WebPFree(encoded);
    return result;
}

int32_t silex_image_codec_result_status(const ImageCodecResult *result) {
    return result == NULL ? IMAGE_CODEC_OUT_OF_MEMORY : result->status;
}

int32_t silex_image_codec_result_width(const ImageCodecResult *result) {
    return result == NULL ? 0 : result->width;
}

int32_t silex_image_codec_result_height(const ImageCodecResult *result) {
    return result == NULL ? 0 : result->height;
}

size_t silex_image_codec_result_size(const ImageCodecResult *result) {
    return result == NULL ? 0 : result->byte_count;
}

const uint8_t *silex_image_codec_result_bytes(const ImageCodecResult *result) {
    return result == NULL ? NULL : result->bytes;
}

void silex_image_codec_result_destroy(ImageCodecResult *result) {
    if (result != NULL) {
        free(result->bytes);
        free(result);
    }
}
