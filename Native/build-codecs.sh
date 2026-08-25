#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: Native/build-codecs.sh /path/to/libjpeg-turbo-3.2.0 /path/to/libwebp-1.6.0" >&2
    exit 2
fi

image_native_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
image_package_dir=$(CDPATH= cd -- "$image_native_dir/.." && pwd)
image_jpeg_source=$1
image_webp_source=$2
image_build_root=$(mktemp -d /private/tmp/silex-image-codecs.XXXXXX)
image_zig_cache="$image_build_root/zig-cache"
trap 'rm -rf "$image_build_root"' EXIT HUP INT TERM

build_jpeg() {
    image_name=$1
    image_system=$2
    image_processor=$3
    image_compiler=$4
    image_install="$image_build_root/install-jpeg-$image_name"
    image_build="$image_build_root/build-jpeg-$image_name"
    env ZIG_GLOBAL_CACHE_DIR="$image_zig_cache" cmake \
        -S "$image_jpeg_source" \
        -B "$image_build" \
        -DCMAKE_SYSTEM_NAME="$image_system" \
        -DCMAKE_SYSTEM_PROCESSOR="$image_processor" \
        -DCMAKE_C_COMPILER="$image_compiler" \
        -DCMAKE_AR="$image_native_dir/Toolchains/zig-ar" \
        -DCMAKE_RANLIB="$image_native_dir/Toolchains/zig-ranlib" \
        -DCMAKE_INSTALL_PREFIX="$image_install" \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_SHARED=OFF \
        -DENABLE_STATIC=ON \
        -DWITH_SIMD=OFF \
        -DWITH_TOOLS=OFF \
        -DWITH_TESTS=OFF \
        -DWITH_TURBOJPEG=ON
    env ZIG_GLOBAL_CACHE_DIR="$image_zig_cache" cmake --build "$image_build" \
        --target turbojpeg-static -j 8
}

build_webp() {
    image_name=$1
    image_system=$2
    image_processor=$3
    image_compiler=$4
    image_simd=$5
    image_install="$image_build_root/install-webp-$image_name"
    image_build="$image_build_root/build-webp-$image_name"
    env ZIG_GLOBAL_CACHE_DIR="$image_zig_cache" cmake \
        -S "$image_webp_source" \
        -B "$image_build" \
        -DCMAKE_SYSTEM_NAME="$image_system" \
        -DCMAKE_SYSTEM_PROCESSOR="$image_processor" \
        -DCMAKE_C_COMPILER="$image_compiler" \
        -DCMAKE_AR="$image_native_dir/Toolchains/zig-ar" \
        -DCMAKE_RANLIB="$image_native_dir/Toolchains/zig-ranlib" \
        -DCMAKE_INSTALL_PREFIX="$image_install" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DWEBP_ENABLE_SIMD="$image_simd" \
        -DWEBP_USE_THREAD=OFF \
        -DWEBP_BUILD_ANIM_UTILS=OFF \
        -DWEBP_BUILD_CWEBP=OFF \
        -DWEBP_BUILD_DWEBP=OFF \
        -DWEBP_BUILD_GIF2WEBP=OFF \
        -DWEBP_BUILD_IMG2WEBP=OFF \
        -DWEBP_BUILD_VWEBP=OFF \
        -DWEBP_BUILD_WEBPINFO=OFF \
        -DWEBP_BUILD_LIBWEBPMUX=OFF \
        -DWEBP_BUILD_WEBPMUX=OFF \
        -DWEBP_BUILD_EXTRAS=OFF
    env ZIG_GLOBAL_CACHE_DIR="$image_zig_cache" cmake --build "$image_build" \
        --target webp -j 8
}

build_target() {
    image_name=$1
    image_system=$2
    image_processor=$3
    image_compiler=$4
    image_simd=$5
    image_extension=$6
    image_prefix=$7
    image_destination="$image_package_dir/Boundary/$image_name"

    build_jpeg "$image_name" "$image_system" "$image_processor" "$image_compiler"
    build_webp "$image_name" "$image_system" "$image_processor" "$image_compiler" "$image_simd"
    mkdir -p "$image_destination"

    env ZIG_GLOBAL_CACHE_DIR="$image_zig_cache" "$image_compiler" \
        -O3 -DNDEBUG \
        -I"$image_jpeg_source/src" \
        -I"$image_webp_source" \
        -c "$image_native_dir/ImageCodecs.c" \
        -o "$image_build_root/ImageCodecs-$image_name.o"
    rm -f "$image_destination/${image_prefix}ImageCodecs.$image_extension"
    "$image_native_dir/Toolchains/zig-ar" rcs \
        "$image_destination/${image_prefix}ImageCodecs.$image_extension" \
        "$image_build_root/ImageCodecs-$image_name.o"
    cp "$image_build_root/build-jpeg-$image_name/libturbojpeg.a" \
        "$image_destination/${image_prefix}turbojpeg.$image_extension"
    cp "$image_build_root/build-webp-$image_name/libwebp.a" \
        "$image_destination/${image_prefix}webp.$image_extension"
    cp "$image_build_root/build-webp-$image_name/libsharpyuv.a" \
        "$image_destination/${image_prefix}sharpyuv.$image_extension"
}

build_target macos-arm64 Darwin arm64 cc OFF a lib
build_target linux-x64 Linux x86_64 "$image_native_dir/Toolchains/zig-cc-linux-x64" ON a lib
build_target windows-x64 Windows x86_64 "$image_native_dir/Toolchains/zig-cc-windows-x64" ON lib ""
build_target windows-arm64 Windows aarch64 "$image_native_dir/Toolchains/zig-cc-windows-arm64" ON lib ""

echo "Image codec archives rebuilt in $image_package_dir/Boundary"
