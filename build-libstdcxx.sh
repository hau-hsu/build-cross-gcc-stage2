#!/usr/bin/env bash
set -u
set -e
set -x

GCC_SRC=$(realpath $1)
RISCV_TOOLCHAIN_PATH=$(realpath $2)

BUILD_PATH=$(pwd)/build
INSTALL_PATH=$BUILD_PATH/install

TARGET=riscv64-unknown-elf

# Install prerequisites
cd $GCC_SRC
contrib/download_prerequisites
mkdir -p $INSTALL_PATH/$TARGET/bin
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-as $INSTALL_PATH/$TARGET/bin/as
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-ld $INSTALL_PATH/$TARGET/bin/ld
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-ld.bfd $INSTALL_PATH/$TARGET/bin/ld.bfd
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-ranlib $INSTALL_PATH/$TARGET/bin/ranlib
cp $RISCV_TOOLCHAIN_PATH/bin/${TARGET}-ar $INSTALL_PATH/$TARGET/bin/ar

# Build libstdc++ in GCC
mkdir -p $BUILD_PATH
cd $BUILD_PATH
$GCC_SRC/configure \
  --target=$TARGET \
  --prefix=$INSTALL_PATH \
  --with-pkgversion='SiFive GCC 8.3.0-2019.08.0' \
  --with-bugurl=https://github.com/sifive/freedom-tools/issues \
  --disable-shared \
  --disable-threads \
  --enable-languages=c,c++ \
  --enable-tls \
  --with-newlib \
  --with-sysroot=$RISCV_TOOLCHAIN_PATH/$TARGET \
  --with-native-system-header-dir=/include \
  --disable-libmudflap \
  --disable-libssp \
  --disable-libquadmath \
  --disable-libgomp \
  --disable-nls \
  --disable-tm-clone-registry \
  --src=$GCC_SRC \
  --with-system-zlib \
  --enable-checking=yes \
  --enable-multilib \
  --with-abi=lp64d \
  --with-arch=rv64imafdc \
  CFLAGS=-O2 \
  CXXFLAGS=-O2 \
  'CFLAGS_FOR_TARGET=-Os  -mcmodel=medany' \
  'CXXFLAGS_FOR_TARGET=-Os  -mcmodel=medany -fno-exceptions'
make -j
make install

# Copy new libstdc++ to toolchain
