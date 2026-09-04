#!/bin/sh
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "usage: Native/build-codecs.sh /path/to/libjpeg-turbo-3.2.0 /path/to/libwebp-1.6.0 [established|macos-x64|linux-arm64]" >&2
    exit 2
fi

image_native_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
image_package_dir=$(CDPATH= cd -- "$image_native_dir/.." && pwd)
image_jpeg_source=$1
image_webp_source=$2
image_requested_target=${3:-established}
image_build_root=$(mktemp -d /private/tmp/silex-image-codecs.XXXXXX)
image_zig_cache="$image_build_root/zig-cache"
export SOURCE_DATE_EPOCH=0
export ZERO_AR_DATE=1
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
        -DCMAKE_OSX_ARCHITECTURES="$image_osx_architecture" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$image_osx_deployment_target" \
        "-DCMAKE_C_FLAGS_RELEASE=$image_target_c_flags -O3 -g0 -DNDEBUG -ffile-prefix-map=$image_build_root=/silex-build -ffile-prefix-map=$image_jpeg_source=/sources/libjpeg-turbo -ffile-prefix-map=$image_package_dir=/sources/image" \
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
        -DCMAKE_OSX_ARCHITECTURES="$image_osx_architecture" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$image_osx_deployment_target" \
        "-DCMAKE_C_FLAGS_RELEASE=$image_target_c_flags -O3 -g0 -DNDEBUG -ffile-prefix-map=$image_build_root=/silex-build -ffile-prefix-map=$image_webp_source=/sources/libwebp -ffile-prefix-map=$image_package_dir=/sources/image" \
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
    image_target_c_flags=
    image_osx_architecture=
    image_osx_deployment_target=
    if [ "$image_name" = macos-x64 ]; then
        image_target_c_flags="-arch x86_64 -mmacosx-version-min=11.0"
        image_osx_architecture=x86_64
        image_osx_deployment_target=11.0
    elif [ "$image_name" = linux-arm64 ]; then
        image_target_c_flags=-mno-outline-atomics
    fi
    image_destination="$image_package_dir/Boundary/$image_name"

    build_jpeg "$image_name" "$image_system" "$image_processor" "$image_compiler"
    build_webp "$image_name" "$image_system" "$image_processor" "$image_compiler" "$image_simd"
    mkdir -p "$image_destination"

    env ZIG_GLOBAL_CACHE_DIR="$image_zig_cache" "$image_compiler" \
        $image_target_c_flags -O3 -g0 -DNDEBUG \
        -ffile-prefix-map="$image_build_root"=/silex-build \
        -ffile-prefix-map="$image_package_dir"=/sources/image \
        -I"$image_jpeg_source/src" \
        -I"$image_webp_source" \
        -c "$image_native_dir/ImageCodecs.c" \
        -o "$image_build_root/ImageCodecs-$image_name.o"
    rm -f "$image_destination/${image_prefix}ImageCodecs.$image_extension"
    "$image_native_dir/Toolchains/zig-ar" rcsD \
        "$image_destination/${image_prefix}ImageCodecs.$image_extension" \
        "$image_build_root/ImageCodecs-$image_name.o"
    cp "$image_build_root/build-jpeg-$image_name/libturbojpeg.a" \
        "$image_destination/${image_prefix}turbojpeg.$image_extension"
    cp "$image_build_root/build-webp-$image_name/libwebp.a" \
        "$image_destination/${image_prefix}webp.$image_extension"
    cp "$image_build_root/build-webp-$image_name/libsharpyuv.a" \
        "$image_destination/${image_prefix}sharpyuv.$image_extension"
}

case "$image_requested_target" in
    established)
        build_target macos-arm64 Darwin arm64 cc OFF a lib
        build_target linux-x64 Linux x86_64 "$image_native_dir/Toolchains/zig-cc-linux-x64" ON a lib
        build_target windows-x64 Windows x86_64 "$image_native_dir/Toolchains/zig-cc-windows-x64" ON lib ""
        build_target windows-arm64 Windows aarch64 "$image_native_dir/Toolchains/zig-cc-windows-arm64" ON lib ""
        ;;
    macos-x64)
        [ "$(uname -s)" = Darwin ] || {
            echo "macos-x64 must be built on macOS" >&2
            exit 1
        }
        build_target macos-x64 Darwin x86_64 cc OFF a lib
        ;;
    linux-arm64)
        build_target linux-arm64 Linux aarch64 "$image_native_dir/Toolchains/zig-cc-linux-arm64" OFF a lib
        ;;
    *)
        echo "unsupported Image target: $image_requested_target" >&2
        exit 2
        ;;
esac

echo "Image codec archives rebuilt in $image_package_dir/Boundary"
