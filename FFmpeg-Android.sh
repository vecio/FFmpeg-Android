#!/bin/bash
#
# FFmpeg-Android, a bash script to build FFmpeg for Android.
#
# Copyright (c) 2012 Cedric Fung <root@vec.io>
#
# FFmpeg-Android will build FFmpeg for Android automatically,
# with patches from VPlayer's Android version <https://vplayer.net/>.
#
# FFmpeg-Android is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.

# FFmpeg-Android is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with FFmpeg-Android; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#
#
# Instruction:
#
# 0. Install git and Android ndk
# 1. $ export ANDROID_NDK=/path/to/your/android-ndk
# 2. $ ./FFmpeg-Android.sh
# 3. libffmpeg.so will be built to build/ffmpeg/{neon,armv7,vfp,armv6,x86}/
#
#


DEST=`pwd`/build/ffmpeg && rm -rf $DEST
SOURCE=`pwd`/ffmpeg

if [ -d ffmpeg ]; then
  cd ffmpeg
else
  git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
  cd ffmpeg
fi

git reset --hard
git clean -f -d
git checkout `cat ../ffmpeg-version`
patch -p1 <../FFmpeg-VPlayer.patch
[ $PIPESTATUS == 0 ] || exit 1

git log --pretty=format:%H -1 > ../ffmpeg-version

TOOLCHAIN_PREFIX=/tmp/vplayer
$ANDROID_NDK/build/tools/make-standalone-toolchain.sh --platform=android-14 --install-dir=$TOOLCHAIN_PREFIX-arm --arch=arm
$ANDROID_NDK/build/tools/make-standalone-toolchain.sh --platform=android-14 --install-dir=$TOOLCHAIN_PREFIX-x86 --arch=x86 --toolchain=x86-4.8 #using 4.8 instead of default 4.6 because of http://www.ffmpeg.org/faq.html#error_003a-can_0027t-find-a-register-in-class-_0027GENERAL_005fREGS_0027-while-reloading-_0027asm_0027 

export PATH=$TOOLCHAIN_PREFIX-arm/bin:$TOOLCHAIN_PREFIX-x86/bin:$PATH

CFLAGS="-O3 -Wall -pipe -fpic -fasm \
  -finline-limit=300 -ffast-math \
  -fmodulo-sched -fmodulo-sched-allow-regmoves \
  -Wno-psabi -Wa,--noexecstack \
  -DANDROID -DNDEBUG"

FFMPEG_FLAGS="--target-os=linux \
  --enable-cross-compile \
  --enable-shared \
  --disable-symver \
  --disable-doc \
  --disable-ffplay \
  --disable-ffmpeg \
  --disable-ffprobe \
  --disable-ffserver \
  --disable-avdevice \
  --disable-avfilter \
  --disable-encoders \
  --disable-muxers \
  --disable-bsfs \
  --disable-filters \
  --disable-devices \
  --disable-everything \
  --enable-protocols  \
  --enable-parsers \
  --enable-demuxers \
  --disable-demuxer=sbg \
  --enable-decoders \
  --enable-network \
  --enable-swscale  \
  --enable-asm \
  --enable-version3"


for version in neon armv7 vfp armv6 x86; do

  cd $SOURCE

  case $version in
    neon)
      TARGET_ARCH=arm
      EXTRA_CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=softfp -mvectorize-with-neon-quad"
      EXTRA_LDFLAGS="-Wl,--fix-cortex-a8"
      ;;
    armv7)
      TARGET_ARCH=arm
      EXTRA_CFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp"
      EXTRA_LDFLAGS="-Wl,--fix-cortex-a8"
      ;;
    vfp)
      TARGET_ARCH=arm
      EXTRA_CFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=softfp"
      EXTRA_LDFLAGS=""
      ;;
    armv6)
      TARGET_ARCH=arm
      EXTRA_CFLAGS="-march=armv6"
      EXTRA_LDFLAGS=""
      ;;
    x86)
      TARGET_ARCH=x86
      EXTRA_CFLAGS="-mtune=atom -mssse3 -mfpmath=sse"
      EXTRA_LDFLAGS=""
      EXTRA_FFMPEG_FLAGS="--disable-avx"
      ;;
    *)
      EXTRA_CFLAGS=""
      EXTRA_LDFLAGS=""
      ;;
  esac

  case $TARGET_ARCH in
    arm)
      CROSS_PREFIX=arm-linux-androideabi
      EXTRA_CFLAGS="$EXTRA_CFLAGS -fstrict-aliasing -Werror=strict-aliasing -mthumb -D__ARM_ARCH_5__ -D__ARM_ARCH_5E__ -D__ARM_ARCH_5T__ -D__ARM_ARCH_5TE__"
    ;;
    x86)
      CROSS_PREFIX=i686-linux-android
      EXTRA_OBJS="libswscale/x86/*.o libswresample/x86/*.o"
    ;;
  esac

  PREFIX="$DEST/$version" && mkdir -p $PREFIX
  FFMPEG_FLAGS="$FFMPEG_FLAGS --arch=$TARGET_ARCH --cross-prefix=$CROSS_PREFIX- --prefix=$PREFIX $EXTRA_FFMPEG_FLAGS"

  export CC="ccache ${CROSS_PREFIX}-gcc"
  export LD=$CROSS_PREFIX-ld
  export AR=$CROSS_PREFIX-ar

  ./configure $FFMPEG_FLAGS --extra-cflags="$CFLAGS $EXTRA_CFLAGS" --extra-ldflags="$EXTRA_LDFLAGS" | tee $PREFIX/configuration.txt
  cp config.* $PREFIX
  [ $PIPESTATUS == 0 ] || exit 1

  make clean
  make -j4 || exit 1
  make install || exit 1

  rm libavcodec/inverse.o
  $CC -lm -lz -shared --sysroot=$TOOLCHAIN_PREFIX-$TARGET_ARCH/sysroot/ -Wl,--no-undefined -Wl,-z,noexecstack $EXTRA_LDFLAGS libavutil/*.o libavutil/$TARGET_ARCH/*.o libavcodec/*.o libavcodec/$TARGET_ARCH/*.o libavformat/*.o libswresample/*.o libswscale/*.o $EXTRA_OBJS -o $PREFIX/libffmpeg.so

  cp $PREFIX/libffmpeg.so $PREFIX/libffmpeg-debug.so
  $CROSS_PREFIX-strip --strip-unneeded $PREFIX/libffmpeg.so

done
